package control

import (
	"bytes"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"sync"
	"syscall"
	"time"
	"unsafe"
)

const guestCID = 77
const guestPort = 8788
const guestMaxRequest = 4096
const guestMaxResponse = 1 << 20
const guestControlKey = "/var/lib/redroid/vsock-auth/key"

type sockaddrVM struct {
	Family   uint16
	Reserved uint16
	Port     uint32
	CID      uint32
	Zero     [4]byte
}
type guestResponse struct {
	Version          int    `json:"version"`
	ID               string `json:"id"`
	Op               string `json:"op,omitempty"`
	OK               bool   `json:"ok"`
	Error            string `json:"error,omitempty"`
	State            string `json:"state,omitempty"`
	ContainerRunning bool   `json:"container_running,omitempty"`
	BootCompleted    bool   `json:"boot_completed,omitempty"`
	Logs             string `json:"logs,omitempty"`
}

type vsockAddr struct{ cid, port uint32 }

func (a vsockAddr) Network() string { return "vsock" }
func (a vsockAddr) String() string  { return fmt.Sprintf("%d:%d", a.cid, a.port) }

// net.FileConn does not support AF_VSOCK. Keep the connected descriptor in a
// small net.Conn implementation and use socket receive/send timeouts for the
// net.Conn deadline contract.
type vsockConn struct {
	fd            int
	remote        vsockAddr
	readMu        sync.Mutex
	writeMu       sync.Mutex
	deadlineMu    sync.Mutex
	readDeadline  time.Time
	writeDeadline time.Time
	closeOnce     sync.Once
	closeErr      error
}

func (c *vsockConn) Read(p []byte) (int, error) {
	c.readMu.Lock()
	defer c.readMu.Unlock()
	for {
		if err := c.setTimeout(syscall.SO_RCVTIMEO, c.currentReadDeadline()); err != nil {
			return 0, err
		}
		n, err := syscall.Read(c.fd, p)
		if err == syscall.EINTR {
			continue
		}
		if err == syscall.EAGAIN || err == syscall.EWOULDBLOCK {
			return n, os.ErrDeadlineExceeded
		}
		if err == nil && n == 0 && len(p) > 0 {
			return 0, io.EOF
		}
		return n, err
	}
}

func (c *vsockConn) Write(p []byte) (int, error) {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	written := 0
	for written < len(p) {
		if err := c.setTimeout(syscall.SO_SNDTIMEO, c.currentWriteDeadline()); err != nil {
			return written, err
		}
		n, err := syscall.Write(c.fd, p[written:])
		if err == syscall.EINTR {
			continue
		}
		if err == syscall.EAGAIN || err == syscall.EWOULDBLOCK {
			return written, os.ErrDeadlineExceeded
		}
		if err != nil {
			return written, err
		}
		if n == 0 {
			return written, io.ErrShortWrite
		}
		written += n
	}
	return written, nil
}

func (c *vsockConn) Close() error {
	c.closeOnce.Do(func() { c.closeErr = syscall.Close(c.fd) })
	return c.closeErr
}
func (c *vsockConn) LocalAddr() net.Addr  { return vsockAddr{cid: 0, port: 0} }
func (c *vsockConn) RemoteAddr() net.Addr { return c.remote }
func (c *vsockConn) SetDeadline(t time.Time) error {
	c.deadlineMu.Lock()
	c.readDeadline, c.writeDeadline = t, t
	c.deadlineMu.Unlock()
	if err := c.setTimeout(syscall.SO_RCVTIMEO, t); err != nil {
		return err
	}
	return c.setTimeout(syscall.SO_SNDTIMEO, t)
}
func (c *vsockConn) SetReadDeadline(t time.Time) error {
	c.deadlineMu.Lock()
	c.readDeadline = t
	c.deadlineMu.Unlock()
	return c.setTimeout(syscall.SO_RCVTIMEO, t)
}
func (c *vsockConn) SetWriteDeadline(t time.Time) error {
	c.deadlineMu.Lock()
	c.writeDeadline = t
	c.deadlineMu.Unlock()
	return c.setTimeout(syscall.SO_SNDTIMEO, t)
}
func (c *vsockConn) currentReadDeadline() time.Time {
	c.deadlineMu.Lock()
	defer c.deadlineMu.Unlock()
	return c.readDeadline
}
func (c *vsockConn) currentWriteDeadline() time.Time {
	c.deadlineMu.Lock()
	defer c.deadlineMu.Unlock()
	return c.writeDeadline
}
func (c *vsockConn) setTimeout(option int, deadline time.Time) error {
	var tv syscall.Timeval
	if !deadline.IsZero() {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			tv = syscall.Timeval{Usec: 1}
		} else {
			tv = syscall.NsecToTimeval(remaining.Nanoseconds())
			if tv.Sec == 0 && tv.Usec == 0 {
				tv.Usec = 1
			}
		}
	}
	return syscall.SetsockoptTimeval(c.fd, syscall.SOL_SOCKET, option, &tv)
}

func dialGuest(timeout time.Duration) (net.Conn, error) {
	fd, e := syscall.Socket(40, syscall.SOCK_STREAM|syscall.SOCK_CLOEXEC, 0)
	if e != nil {
		return nil, e
	}
	closeFD := true
	defer func() {
		if closeFD {
			syscall.Close(fd)
		}
	}()
	if e = syscall.SetNonblock(fd, true); e != nil {
		return nil, e
	}
	addr := sockaddrVM{Family: 40, Port: guestPort, CID: guestCID}
	_, _, errno := syscall.RawSyscall(syscall.SYS_CONNECT, uintptr(fd), uintptr(unsafe.Pointer(&addr)), unsafe.Sizeof(addr))
	if errno != 0 && errno != syscall.EINPROGRESS && errno != syscall.EALREADY && errno != syscall.EINTR {
		return nil, errno
	}
	if errno != 0 {
		if e = waitVsockConnect(fd, timeout); e != nil {
			return nil, e
		}
	}
	if e = syscall.SetNonblock(fd, false); e != nil {
		return nil, e
	}
	conn := &vsockConn{fd: fd, remote: vsockAddr{cid: guestCID, port: guestPort}}
	if e = conn.SetDeadline(time.Now().Add(timeout)); e != nil {
		return nil, e
	}
	closeFD = false
	return conn, nil
}

func waitVsockConnect(fd int, timeout time.Duration) error {
	var bounds syscall.FdSet
	if fd < 0 || fd >= len(bounds.Bits)*64 {
		return errors.New("VSOCK file descriptor exceeds select bounds")
	}
	deadline := time.Now().Add(timeout)
	for {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			return errors.New("VSOCK connection timed out")
		}
		var writable syscall.FdSet
		writable.Bits[fd/64] |= int64(1) << uint(fd%64)
		timeval := syscall.NsecToTimeval(remaining.Nanoseconds())
		ready, err := syscall.Select(fd+1, nil, &writable, nil, &timeval)
		if err == syscall.EINTR {
			continue
		}
		if err != nil {
			return err
		}
		if ready == 0 {
			return errors.New("VSOCK connection timed out")
		}
		socketError, err := syscall.GetsockoptInt(fd, syscall.SOL_SOCKET, syscall.SO_ERROR)
		if err != nil {
			return err
		}
		if socketError != 0 {
			return syscall.Errno(socketError)
		}
		return nil
	}
}

func guestCall(op string, seconds int) (guestResponse, error) {
	return guestCallWithKey(op, seconds, "")
}

func makeGuestRequest(op string, seconds int, publicKey string, nonce []byte, timestamp time.Time, secret []byte) ([]byte, error) {
	if len(secret) != 32 || len(nonce) != 16 {
		return nil, errors.New("guest request requires a 32-byte secret and 16-byte nonce")
	}
	q := map[string]any{
		"version":   1,
		"id":        "host-controller",
		"op":        op,
		"nonce":     hex.EncodeToString(nonce),
		"timestamp": timestamp.Unix(),
	}
	if seconds > 0 {
		q["timeout_seconds"] = seconds
	}
	if publicKey != "" {
		q["public_key"] = publicKey
	}
	canonical, e := json.Marshal(q)
	if e != nil {
		return nil, e
	}
	mac := hmac.New(sha256.New, secret)
	_, _ = mac.Write(canonical)
	q["auth"] = hex.EncodeToString(mac.Sum(nil))
	return json.Marshal(q)
}

func guestCallWithKey(op string, seconds int, publicKey string) (guestResponse, error) {
	dialTimeout := 10 * time.Second
	timeout := 10 * time.Second
	if op == "wait-ready" && seconds > 0 {
		timeout = time.Duration(seconds+10) * time.Second
		dialTimeout = 3 * time.Second
	}
	if op == "shutdown" {
		timeout = 75 * time.Second
	}
	c, e := dialGuest(dialTimeout)
	if e != nil {
		return guestResponse{}, fmt.Errorf("connect guest vsock CID %d port %d: %w", guestCID, guestPort, e)
	}
	defer c.Close()
	if e = c.SetDeadline(time.Now().Add(timeout)); e != nil {
		return guestResponse{}, e
	}
	secretHex, e := os.ReadFile(guestControlKey)
	if e != nil {
		return guestResponse{}, fmt.Errorf("read guest-control authentication key: %w", e)
	}
	secret, e := hex.DecodeString(string(bytes.TrimSpace(secretHex)))
	if e != nil || len(secret) != 32 {
		return guestResponse{}, errors.New("guest-control authentication key is invalid")
	}
	nonceBytes := make([]byte, 16)
	if _, e = rand.Read(nonceBytes); e != nil {
		return guestResponse{}, fmt.Errorf("create VSOCK request nonce: %w", e)
	}
	b, e := makeGuestRequest(op, seconds, publicKey, nonceBytes, time.Now(), secret)
	if e != nil {
		return guestResponse{}, e
	}
	if len(b) > guestMaxRequest {
		return guestResponse{}, errors.New("guest request too large")
	}
	var h [4]byte
	binary.BigEndian.PutUint32(h[:], uint32(len(b)))
	if _, e = c.Write(h[:]); e != nil {
		return guestResponse{}, e
	}
	if _, e = c.Write(b); e != nil {
		return guestResponse{}, e
	}
	if _, e = io.ReadFull(c, h[:]); e != nil {
		return guestResponse{}, e
	}
	n := binary.BigEndian.Uint32(h[:])
	if n == 0 || n > guestMaxResponse {
		return guestResponse{}, errors.New("invalid guest response size")
	}
	b = make([]byte, n)
	if _, e = io.ReadFull(c, b); e != nil {
		return guestResponse{}, e
	}
	var r guestResponse
	if e = json.Unmarshal(b, &r); e != nil {
		return r, e
	}
	if r.Version != 1 || r.ID != "host-controller" {
		return r, errors.New("guest protocol identity mismatch")
	}
	if !r.OK {
		return r, errors.New(r.Error)
	}
	return r, nil
}
