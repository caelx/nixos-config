package gateway

import (
	"bufio"
	"context"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"ghostship.local/redroid-lab/internal/protocol"
)

func TestBearerAuthentication(t *testing.T) {
	s := New()
	s.token = "runtime-token-with-enough-entropy"
	for _, tc := range []struct {
		name, auth string
		want       int
	}{{"missing", "", 401}, {"wrong", "Bearer wrong", 401}, {"right", "Bearer runtime-token-with-enough-entropy", 404}} {
		t.Run(tc.name, func(t *testing.T) {
			r := httptest.NewRequest("GET", "/unknown", nil)
			r.Header.Set("Authorization", tc.auth)
			w := httptest.NewRecorder()
			s.ServeHTTP(w, r)
			if w.Code != tc.want {
				t.Fatalf("status %d want %d", w.Code, tc.want)
			}
		})
	}
}

func TestStreamADBDrainsLargeOutputBeforeExit(t *testing.T) {
	dir := t.TempDir()
	adb := filepath.Join(dir, "adb")
	shellPath, err := exec.LookPath("sh")
	if err != nil {
		t.Fatal(err)
	}
	ddPath, err := exec.LookPath("dd")
	if err != nil {
		t.Fatal(err)
	}
	trPath, err := exec.LookPath("tr")
	if err != nil {
		t.Fatal(err)
	}
	script := fmt.Sprintf("#!%s\n%s if=/dev/zero bs=300000 count=1 2>/dev/null | %s '\\000' x\n", shellPath, ddPath, trPath)
	if err := os.WriteFile(adb, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	oldADBPath := adbPath
	adbPath = adb
	t.Cleanup(func() { adbPath = oldADBPath })

	server, client := net.Pipe()
	defer client.Close()
	serverRW := bufio.NewReadWriter(bufio.NewReader(server), bufio.NewWriter(server))
	clientReader := bufio.NewReader(client)
	result := make(chan error, 1)
	go func() {
		defer server.Close()
		result <- streamADB(context.Background(), server, serverRW, nil)
	}()
	if err := protocol.WriteFrame(client, protocol.StreamFrame{Version: protocol.Version, Type: "stdin-eof"}); err != nil {
		t.Fatal(err)
	}
	var total int
	for {
		var frame protocol.StreamFrame
		if err := protocol.ReadFrame(clientReader, &frame); err != nil {
			t.Fatal(err)
		}
		if frame.Type == "stdout" {
			total += len(frame.Data)
		}
		if frame.Type == "exit" {
			break
		}
		if frame.Type == "error" {
			t.Fatalf("stream returned error frame: %s", frame.Data)
		}
	}
	if total != 300000 {
		t.Fatalf("received %d output bytes, want 300000", total)
	}
	select {
	case err := <-result:
		if err != nil {
			t.Fatalf("streamADB: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("streamADB did not finish after output EOF")
	}
}

func TestRPCRejectsMalformedAndOversizedBodies(t *testing.T) {
	s := New()
	s.token = "runtime-token-with-enough-entropy"
	for _, body := range []string{"{", strings.Repeat("x", protocol.MaxFrame+1)} {
		r := httptest.NewRequest(http.MethodPost, "/rpc", strings.NewReader(body))
		r.Header.Set("Authorization", "Bearer "+s.token)
		w := httptest.NewRecorder()
		s.ServeHTTP(w, r)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("status %d for request body length %d", w.Code, len(body))
		}
	}
}

func TestNonceSingleUseAndExpiry(t *testing.T) {
	s := New()
	s.nonces["once"] = nonce{session: "s", expires: time.Now().Add(time.Minute)}
	got, ok := s.consumeNonce("once")
	if !ok || got.session != "s" {
		t.Fatal("nonce not issued")
	}
	if _, ok = s.consumeNonce("once"); ok {
		t.Fatal("replayed nonce accepted")
	}
	s.nonces["old"] = nonce{session: "x", expires: time.Now().Add(-time.Second)}
	if _, ok = s.consumeNonce("old"); ok {
		t.Fatal("expired nonce accepted")
	}
}

func TestADBTargetOverridesRejected(t *testing.T) {
	for _, args := range [][]string{{"-L", "tcp:0.0.0.0:5037", "shell"}, {"-s", "other", "shell"}, {"connect", "host:5555"}, {"kill-server"}} {
		if _, e := adbArgs(args); e == nil {
			t.Fatalf("accepted unsafe adb argv %q", args)
		}
	}
	if _, e := adbArgs([]string{"shell", "id"}); e != nil {
		t.Fatal(e)
	}
}

func TestBoundedTransferArgsUseFixedADBTarget(t *testing.T) {
	for _, args := range [][]string{{"install", "/tmp/app.apk"}, {"push", "/tmp/data", "/sdcard/data"}, {"pull", "/sdcard/data", "/tmp/data"}} {
		got, err := transferADBArgs(args)
		if err != nil {
			t.Fatalf("transfer args %q: %v", args, err)
		}
		if len(got) < 6 || got[0] != "-L" || got[1] != adbSocket || got[2] != "-s" || got[3] != adbDevice {
			t.Fatalf("transfer did not use fixed ADB socket/device: %q", got)
		}
	}
	for _, args := range [][]string{{"shell", "id"}, {"connect", "host:5555"}, {"push", "x\x00y", "z"}} {
		if _, err := transferADBArgs(args); err == nil {
			t.Fatalf("unsafe transfer accepted: %q", args)
		}
	}
}
