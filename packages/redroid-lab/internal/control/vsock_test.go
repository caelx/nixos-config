package control

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"syscall"
	"testing"
	"time"
)

func newSocketpairConn(t *testing.T) (*vsockConn, int) {
	t.Helper()
	fds, err := syscall.Socketpair(syscall.AF_UNIX, syscall.SOCK_STREAM|syscall.SOCK_CLOEXEC, 0)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = syscall.Close(fds[1]) })
	conn := &vsockConn{fd: fds[0]}
	t.Cleanup(func() { _ = conn.Close() })
	return conn, fds[1]
}

func TestVsockConnReturnsEOF(t *testing.T) {
	conn, peer := newSocketpairConn(t)
	if err := syscall.Close(peer); err != nil {
		t.Fatal(err)
	}
	n, err := conn.Read(make([]byte, 1))
	if n != 0 || err != io.EOF {
		t.Fatalf("Read after peer close = (%d, %v), want (0, EOF)", n, err)
	}
}

func TestVsockConnReadDeadlineIsAbsoluteAcrossReads(t *testing.T) {
	conn, peer := newSocketpairConn(t)
	started := time.Now()
	if err := conn.SetReadDeadline(started.Add(150 * time.Millisecond)); err != nil {
		t.Fatal(err)
	}
	go func() {
		for _, delay := range []time.Duration{40 * time.Millisecond, 80 * time.Millisecond, 80 * time.Millisecond} {
			time.Sleep(delay)
			if _, err := syscall.Write(peer, []byte{'x'}); err != nil {
				return
			}
		}
	}()
	buffer := make([]byte, 3)
	n, err := io.ReadFull(conn, buffer)
	if !errors.Is(err, os.ErrDeadlineExceeded) {
		t.Fatalf("ReadFull error = %v, want deadline exceeded (read %d bytes)", err, n)
	}
	if elapsed := time.Since(started); elapsed > 250*time.Millisecond {
		t.Fatalf("absolute read deadline took %s", elapsed)
	}
}

func TestMakeGuestRequestAuthenticatesExactPayload(t *testing.T) {
	secret := make([]byte, 32)
	for i := range secret {
		secret[i] = byte(i)
	}
	nonce := make([]byte, 16)
	for i := range nonce {
		nonce[i] = byte(16 - i)
	}
	now := time.Unix(1_800_000_000, 0)
	payload, err := makeGuestRequest("authorize-adb", 0, "ssh-ed25519 AAAA key", nonce, now, secret)
	if err != nil {
		t.Fatal(err)
	}
	var request map[string]any
	if err := json.Unmarshal(payload, &request); err != nil {
		t.Fatal(err)
	}
	auth, ok := request["auth"].(string)
	if !ok {
		t.Fatal("request has no authentication tag")
	}
	delete(request, "auth")
	canonical, err := json.Marshal(request)
	if err != nil {
		t.Fatal(err)
	}
	wantCanonical := `{"id":"host-controller","nonce":"100f0e0d0c0b0a090807060504030201","op":"authorize-adb","public_key":"ssh-ed25519 AAAA key","timestamp":1800000000,"version":1}`
	if string(canonical) != wantCanonical {
		t.Fatalf("canonical payload differs from Python json.dumps(sort_keys=True) fixture: %s", canonical)
	}
	mac := hmac.New(sha256.New, secret)
	_, _ = mac.Write(canonical)
	if !hmac.Equal([]byte(auth), []byte(hex.EncodeToString(mac.Sum(nil)))) {
		t.Fatal("authentication tag does not match canonical request")
	}
	if request["nonce"] != hex.EncodeToString(nonce) || request["timestamp"] != float64(now.Unix()) {
		t.Fatal("request omitted nonce or timestamp")
	}
}

func TestMakeGuestRequestRejectsInvalidKeyOrNonceSize(t *testing.T) {
	if _, err := makeGuestRequest("status", 0, "", make([]byte, 15), time.Now(), make([]byte, 32)); err == nil {
		t.Fatal("accepted an undersized nonce")
	}
	if _, err := makeGuestRequest("status", 0, "", make([]byte, 16), time.Now(), make([]byte, 31)); err == nil {
		t.Fatal("accepted an undersized secret")
	}
}
