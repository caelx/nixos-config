package control

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"ghostship.local/redroid-lab/internal/protocol"
)

const (
	SocketPath = "/run/redroid/control.sock"
	Unit       = "microvm@android-lab.service"
	DataImage  = "/var/lib/redroid/android-data.ext4"
	StateDir   = "/var/lib/redroid/control"
	GatewayUID = 925
	MaxLease   = 60 * time.Second
	ResetTTL   = 2 * time.Minute
)

type lease struct{ expires time.Time }
type challenge struct {
	generation uint64
	expires    time.Time
}
type Server struct {
	mu           sync.Mutex
	opMu         sync.Mutex
	startMu      sync.Mutex
	leases       map[string]lease
	challenges   map[string]challenge
	generation   uint64
	stateFile    string
	lastActivity time.Time
	idleTimeout  time.Duration
	stopping     bool
}

func New() *Server {
	return &Server{leases: map[string]lease{}, challenges: map[string]challenge{}, stateFile: filepath.Join(StateDir, "generation"), lastActivity: time.Now(), idleTimeout: 15 * time.Minute}
}
func (s *Server) Serve() error {
	if raw := os.Getenv("REDROID_IDLE_TIMEOUT"); raw != "" {
		d, e := time.ParseDuration(raw)
		if e != nil || d < time.Minute || d > 24*time.Hour {
			return errors.New("REDROID_IDLE_TIMEOUT must be a duration from 1m through 24h")
		}
		s.idleTimeout = d
	}
	if e := os.MkdirAll(filepath.Dir(SocketPath), 0755); e != nil {
		return e
	}
	if e := s.loadGeneration(); e != nil {
		return e
	}
	_ = os.Remove(SocketPath)
	l, e := net.Listen("unix", SocketPath)
	if e != nil {
		return e
	}
	defer l.Close()
	if e = os.Chown(SocketPath, 0, GatewayUID); e != nil {
		return e
	}
	if e = os.Chmod(SocketPath, 0660); e != nil {
		return e
	}
	go s.idleLoop()
	for {
		c, e := l.Accept()
		if e != nil {
			return e
		}
		go s.handle(c)
	}
}
func peerUID(c net.Conn) (uint32, error) {
	u, ok := c.(*net.UnixConn)
	if !ok {
		return 0, errors.New("unix socket required")
	}
	raw, e := u.SyscallConn()
	if e != nil {
		return 0, e
	}
	var cred *syscall.Ucred
	var ce error
	e = raw.Control(func(fd uintptr) { cred, ce = syscall.GetsockoptUcred(int(fd), syscall.SOL_SOCKET, syscall.SO_PEERCRED) })
	if e != nil {
		return 0, e
	}
	if ce != nil {
		return 0, ce
	}
	return cred.Uid, nil
}
func (s *Server) handle(c net.Conn) {
	defer c.Close()
	uid, e := peerUID(c)
	if e != nil || uid != GatewayUID {
		return
	}
	_ = c.SetDeadline(time.Now().Add(5 * time.Minute))
	line, e := bufio.NewReader(io.LimitReader(c, protocol.MaxFrame+1)).ReadBytes('\n')
	if e != nil || len(line) > protocol.MaxFrame {
		return
	}
	q, e := decodeRequest(line)
	if e != nil {
		return
	}
	r := s.dispatch(q)
	r.Version = protocol.Version
	r.ID = q.ID
	b, _ := json.Marshal(r)
	if len(b) > protocol.MaxFrame {
		b, _ = json.Marshal(fail(errors.New("controller response too large")))
	}
	_, _ = c.Write(append(b, '\n'))
}

func decodeRequest(line []byte) (protocol.Request, error) {
	var q protocol.Request
	if len(line) > protocol.MaxFrame {
		return q, errors.New("controller request too large")
	}
	d := json.NewDecoder(strings.NewReader(string(line)))
	d.DisallowUnknownFields()
	if e := d.Decode(&q); e != nil {
		return q, e
	}
	var extra any
	if e := d.Decode(&extra); e != io.EOF {
		return q, errors.New("trailing JSON value")
	}
	if q.Version != protocol.Version || q.ID == "" || q.Op == "" || len(q.Args) > 24 {
		return q, errors.New("invalid controller request envelope")
	}
	for k, v := range q.Args {
		if len(k) > 128 || len(v) > 8192 {
			return q, errors.New("controller argument too long")
		}
	}
	return q, nil
}

func (s *Server) loadGeneration() error {
	b, e := os.ReadFile(s.stateFile)
	if os.IsNotExist(e) {
		return nil
	}
	if e != nil {
		return e
	}
	s.generation, e = strconv.ParseUint(strings.TrimSpace(string(b)), 10, 64)
	return e
}
func (s *Server) saveGeneration() error {
	if e := os.MkdirAll(StateDir, 0700); e != nil {
		return e
	}
	tmp := s.stateFile + ".tmp"
	f, e := os.OpenFile(tmp, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0600)
	if e != nil {
		return e
	}
	if _, e = fmt.Fprintf(f, "%d\n", s.generation); e != nil {
		f.Close()
		return e
	}
	if e = f.Sync(); e != nil {
		f.Close()
		return e
	}
	if e = f.Close(); e != nil {
		return e
	}
	if e = os.Rename(tmp, s.stateFile); e != nil {
		return e
	}
	return syncDir(StateDir)
}
func syncDir(p string) error {
	d, e := os.Open(p)
	if e != nil {
		return e
	}
	defer d.Close()
	return d.Sync()
}
func randomID() (string, error) {
	b := make([]byte, 24)
	if _, e := rand.Read(b); e != nil {
		return "", e
	}
	return hex.EncodeToString(b), nil
}
func (s *Server) prune() {
	now := time.Now()
	for id, l := range s.leases {
		if !l.expires.After(now) {
			delete(s.leases, id)
		}
	}
	for id, c := range s.challenges {
		if !c.expires.After(now) {
			delete(s.challenges, id)
		}
	}
}
func (s *Server) dispatch(q protocol.Request) protocol.Response {
	s.mu.Lock()
	s.prune()
	generation := s.generation
	leaseCount := len(s.leases)
	s.mu.Unlock()
	r := protocol.Response{OK: true, Generation: generation}
	switch q.Op {
	case "status":
		active, e := unitActive()
		if e != nil {
			return fail(e)
		}
		guest, ge := guestCall("status", 0)
		status := map[string]any{"active": active, "guest": guest, "guest_error": "", "adb_state": "offline", "boot_completed": false, "root_adb": false, "kernelsu_su": false, "leases": leaseCount, "generation": generation}
		if ge != nil {
			status["guest_error"] = ge.Error()
		}
		if active {
			if adbState, ae := adbFor("get-state"); ae == nil && strings.TrimSpace(adbState) == "device" {
				status["adb_state"] = "device"
				boot, be := adbFor("shell", "getprop", "sys.boot_completed")
				status["boot_completed"] = be == nil && strings.TrimSpace(boot) == "1"
				root, re := adbFor("shell", "id")
				status["root_adb"] = re == nil && strings.Contains(root, "uid=0(root)")
				su, se := adbFor("shell", "su", "-c", "id")
				status["kernelsu_su"] = se == nil && strings.Contains(su, "uid=0(root)")
			}
		}
		r.Data, _ = json.Marshal(status)
	case "start":
		s.mu.Lock()
		s.prune()
		lease := q.Args["lease"]
		_, leaseOK := s.leases[lease]
		startForActiveLease := s.stopping && lease != "" && leaseOK
		s.mu.Unlock()
		if startForActiveLease {
			if e := s.start(); e != nil {
				return fail(e)
			}
			break
		}
		s.opMu.Lock()
		defer s.opMu.Unlock()
		if e := s.start(); e != nil {
			return fail(e)
		}
	case "stop":
		if e := s.stopAndDrain(false); e != nil {
			return fail(e)
		}
	case "restart":
		if e := s.stopAndDrain(true); e != nil {
			return fail(e)
		}
	case "wait":
		s.opMu.Lock()
		defer s.opMu.Unlock()
		if _, e := guestCall("wait-ready", 180); e != nil {
			return fail(e)
		}
		if e := s.verifyRoot(); e != nil {
			return fail(e)
		}
	case "verify-ready":
		if e := s.verifyRoot(); e != nil {
			return fail(e)
		}
	case "logs":
		out, e := fixedOutput("/run/current-system/sw/bin/journalctl", "-u", Unit, "--no-pager", "-n", "200")
		if e != nil {
			return fail(e)
		}
		guest, ge := guestCall("logs", 0)
		if ge == nil {
			out += "\n--- guest ---\n" + guest.Logs
		}
		if len(out) > 128<<10 {
			out = out[len(out)-(128<<10):]
		}
		r.Data, _ = json.Marshal(map[string]string{"logs": out})
	case "acquire", "renew":
		s.mu.Lock()
		defer s.mu.Unlock()
		if s.stopping && q.Op == "acquire" {
			return fail(errors.New("lifecycle stop/reset in progress"))
		}
		ttl := 30 * time.Second
		if x := q.Args["ttl_seconds"]; x != "" {
			n, e := strconv.Atoi(x)
			if e != nil || n < 1 {
				return fail(errors.New("invalid lease TTL"))
			}
			ttl = time.Duration(n) * time.Second
		}
		if ttl > MaxLease {
			ttl = MaxLease
		}
		id := q.Args["lease"]
		if q.Op == "acquire" {
			id, _ = randomID()
			if id == "" {
				return fail(errors.New("random ID generation failed"))
			}
		} else if _, ok := s.leases[id]; !ok {
			return fail(errors.New("lease missing or expired"))
		}
		s.leases[id] = lease{time.Now().Add(ttl)}
		s.lastActivity = time.Now()
		r.Lease = id
	case "release":
		s.mu.Lock()
		delete(s.leases, q.Args["lease"])
		s.lastActivity = time.Now()
		s.mu.Unlock()
	case "keepalive":
		s.mu.Lock()
		if s.stopping && q.Op == "acquire" {
			s.mu.Unlock()
			return fail(errors.New("lifecycle stop/reset in progress"))
		}
		s.lastActivity = time.Now()
		s.mu.Unlock()
	case "reset-challenge":
		id, e := randomID()
		if e != nil {
			return fail(e)
		}
		s.mu.Lock()
		gen := s.generation
		s.challenges[id] = challenge{gen, time.Now().Add(ResetTTL)}
		s.mu.Unlock()
		r.Generation = gen
		r.Lease = id
	case "factory-reset":
		s.opMu.Lock()
		defer s.opMu.Unlock()
		s.mu.Lock()
		s.prune()
		if s.stopping {
			s.mu.Unlock()
			return fail(errors.New("lifecycle operation already in progress"))
		}
		s.stopping = true
		defer func() { s.mu.Lock(); s.stopping = false; s.mu.Unlock() }()
		id := q.Args["challenge"]
		ch, ok := s.challenges[id]
		delete(s.challenges, id)
		gen := s.generation
		leases := len(s.leases)
		s.mu.Unlock()
		if !ok || !ch.expires.After(time.Now()) || ch.generation != gen {
			return fail(errors.New("invalid, expired, or replayed challenge"))
		}
		if q.Args["yes"] != "true" || q.Args["generation"] != strconv.FormatUint(gen, 10) {
			return fail(errors.New("factory reset requires explicit yes and exact generation"))
		}
		if leases > 0 {
			return fail(errors.New("active leases prevent reset"))
		}
		active, e := vmActiveAndExited()
		if e != nil {
			return fail(e)
		}
		if active {
			return fail(errors.New("VM must already be stopped; reset never stops it"))
		}
		if opened, e := diskOpen(); e != nil {
			return fail(e)
		} else if opened {
			return fail(errors.New("data disk is open by a process"))
		}
		if e = s.resetDisk(); e != nil {
			return fail(e)
		}
		s.mu.Lock()
		r.Generation = s.generation
		s.mu.Unlock()
	default:
		return fail(errors.New("unsupported controller operation"))
	}
	return r
}
func fail(e error) protocol.Response {
	return protocol.Response{Version: protocol.Version, OK: false, Error: e.Error()}
}
func unitActive() (bool, error) {
	out, e := fixedOutput("/run/current-system/sw/bin/systemctl", "is-active", Unit)
	if e == nil {
		return strings.TrimSpace(out) == "active", nil
	}
	if strings.TrimSpace(out) == "inactive" || strings.TrimSpace(out) == "failed" {
		return false, nil
	}
	return false, fmt.Errorf("cannot determine VM state: %s", strings.TrimSpace(out))
}
func vmActiveAndExited() (bool, error) {
	active, e := unitActive()
	if e != nil {
		return false, e
	}
	pid, pe := fixedOutput("/run/current-system/sw/bin/systemctl", "show", "-p", "MainPID", "--value", Unit)
	if pe != nil {
		return false, pe
	}
	if strings.TrimSpace(pid) != "0" {
		return false, fmt.Errorf("MicroVM process is still present (MainPID %s)", strings.TrimSpace(pid))
	}
	return active, nil
}
func fixedOutput(path string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 35*time.Second)
	defer cancel()
	c := exec.CommandContext(ctx, path, args...)
	b, e := c.CombinedOutput()
	if e != nil {
		return string(b), e
	}
	return string(b), nil
}
func run(path string, args ...string) error {
	out, e := fixedOutput(path, args...)
	if e != nil {
		return fmt.Errorf("%s: %s", filepath.Base(path), strings.TrimSpace(out))
	}
	return nil
}
func diskOpen() (bool, error) {
	entries, e := os.ReadDir("/proc")
	if e != nil {
		return false, e
	}
	for _, p := range entries {
		if _, e := strconv.Atoi(p.Name()); e != nil {
			continue
		}
		fds, e := os.ReadDir(filepath.Join("/proc", p.Name(), "fd"))
		if e != nil {
			continue
		}
		for _, fd := range fds {
			target, e := os.Readlink(filepath.Join("/proc", p.Name(), "fd", fd.Name()))
			if e == nil && target == DataImage {
				return true, nil
			}
		}
	}
	return false, nil
}
func (s *Server) resetDisk() error {
	if e := recoverResetDisk(); e != nil {
		return e
	}
	if _, e := os.Stat(DataImage); e != nil {
		return fmt.Errorf("persistent disk must exist: %w", e)
	}
	base := "/var/lib/redroid"
	quarantineDir := filepath.Join(base, "quarantine")
	if entries, readErr := os.ReadDir(quarantineDir); readErr == nil {
		for _, entry := range entries {
			if !strings.HasPrefix(entry.Name(), "android-data-") {
				continue
			}
			path := filepath.Join(quarantineDir, entry.Name())
			info, statErr := os.Lstat(path)
			if statErr != nil {
				return statErr
			}
			if !info.Mode().IsRegular() {
				return fmt.Errorf("refusing unexpected quarantine entry %s", entry.Name())
			}
			if removeErr := os.Remove(path); removeErr != nil {
				return fmt.Errorf("remove stale Android data quarantine %s: %w", entry.Name(), removeErr)
			}
		}
		if syncErr := syncDir(quarantineDir); syncErr != nil {
			return syncErr
		}
	} else if !errors.Is(readErr, os.ErrNotExist) {
		return readErr
	}
	tmp := filepath.Join(base, ".android-data.new.ext4")
	if info, e := os.Lstat(tmp); e == nil {
		if !info.Mode().IsRegular() {
			return errors.New("refusing unexpected factory-reset temporary disk")
		}
		if e = os.Remove(tmp); e != nil {
			return fmt.Errorf("remove interrupted factory-reset temporary disk: %w", e)
		}
		if e = syncDir(base); e != nil {
			return e
		}
	} else if !errors.Is(e, os.ErrNotExist) {
		return e
	}
	if e := run("/run/current-system/sw/bin/qemu-img", "create", "-f", "raw", tmp, "32G"); e != nil {
		return e
	}
	if e := run("/run/current-system/sw/bin/chown", "root:redroid-vm-data", tmp); e != nil {
		return e
	}
	if e := os.Chmod(tmp, 0660); e != nil {
		return e
	}
	if e := run("/run/current-system/sw/bin/mkfs.ext4", "-F", "-L", "REDROID_DATA", tmp); e != nil {
		return e
	}
	if e := syncFile(tmp); e != nil {
		return e
	}
	if e := os.MkdirAll(quarantineDir, 0700); e != nil {
		return e
	}
	if e := os.Chown(quarantineDir, 0, 0); e != nil {
		return e
	}
	if e := os.Chmod(quarantineDir, 0700); e != nil {
		return e
	}
	quarantine := filepath.Join(quarantineDir, "android-data-"+time.Now().UTC().Format("20060102T150405.000000000Z"))
	if e := os.Rename(DataImage, quarantine); e != nil {
		return e
	}
	if e := os.Chown(quarantine, 0, 0); e != nil {
		_ = os.Rename(quarantine, DataImage)
		return e
	}
	if e := os.Rename(tmp, DataImage); e != nil {
		_ = os.Rename(quarantine, DataImage)
		return e
	}
	if e := os.Chmod(quarantine, 0600); e != nil {
		return e
	}
	if e := syncDir(base); e != nil {
		return e
	}
	if e := os.Remove(quarantine); e != nil {
		return fmt.Errorf("remove prior Android data image from quarantine: %w", e)
	}
	if e := syncDir(quarantineDir); e != nil {
		return e
	}
	s.mu.Lock()
	s.generation++
	s.mu.Unlock()
	return s.saveGeneration()
}

// recoverResetDisk rolls back an interrupted reset if the original image was
// quarantined before its replacement was installed. If the replacement already
// occupies DataImage, it finalizes cleanup of the old quarantined image before
// the VM starts, so reset data is not left behind after a crash.
func recoverResetDisk() error {
	dataInfo, dataErr := os.Lstat(DataImage)
	dataExists := dataErr == nil
	if dataErr != nil && !errors.Is(dataErr, os.ErrNotExist) {
		return dataErr
	}
	if dataExists && !dataInfo.Mode().IsRegular() {
		return errors.New("refusing unexpected persistent Android data image")
	}
	quarantineDir := "/var/lib/redroid/quarantine"
	entries, e := os.ReadDir(quarantineDir)
	if errors.Is(e, os.ErrNotExist) {
		entries = nil
	} else if e != nil {
		return e
	}
	var candidate string
	var stale []string
	for _, entry := range entries {
		if !strings.HasPrefix(entry.Name(), "android-data-") {
			continue
		}
		path := filepath.Join(quarantineDir, entry.Name())
		info, statErr := os.Lstat(path)
		if statErr != nil {
			return statErr
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("refusing unexpected quarantine entry %s", entry.Name())
		}
		if dataExists {
			stale = append(stale, path)
		} else {
			if candidate != "" {
				return errors.New("multiple quarantined Android data images; manual recovery required")
			}
			candidate = path
		}
	}
	if !dataExists && candidate != "" {
		if e = os.Rename(candidate, DataImage); e != nil {
			return fmt.Errorf("restore interrupted Android data reset: %w", e)
		}
		if e = run("/run/current-system/sw/bin/chown", "root:redroid-vm-data", DataImage); e != nil {
			return e
		}
		if e = os.Chmod(DataImage, 0660); e != nil {
			return e
		}
	}
	tmp := "/var/lib/redroid/.android-data.new.ext4"
	if info, statErr := os.Lstat(tmp); statErr == nil {
		if !info.Mode().IsRegular() {
			return errors.New("refusing unexpected interrupted factory-reset temporary disk")
		}
		if e = os.Remove(tmp); e != nil {
			return fmt.Errorf("remove interrupted factory-reset temporary disk: %w", e)
		}
	} else if !errors.Is(statErr, os.ErrNotExist) {
		return statErr
	}
	for _, path := range stale {
		if e = os.Remove(path); e != nil {
			return fmt.Errorf("remove interrupted factory-reset quarantine image: %w", e)
		}
	}
	if e = syncDir(filepath.Dir(DataImage)); e != nil {
		return e
	}
	if len(stale) > 0 || candidate != "" {
		if e = syncDir(quarantineDir); e != nil {
			return e
		}
	}
	return nil
}

func syncFile(p string) error {
	f, e := os.OpenFile(p, os.O_RDONLY, 0)
	if e != nil {
		return e
	}
	defer f.Close()
	return f.Sync()
}
