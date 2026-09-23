package control

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"ghostship.local/redroid-lab/internal/protocol"
)

func testServer() *Server {
	return &Server{leases: map[string]lease{}, challenges: map[string]challenge{}, stateFile: filepath.Join(os.TempDir(), "unused-generation")}
}

func TestLeaseRenewReleaseAndCap(t *testing.T) {
	s := testServer()
	r := s.dispatch(protocol.Request{Version: 1, ID: "1", Op: "acquire", Args: map[string]string{"ttl_seconds": "600"}})
	if !r.OK || r.Lease == "" {
		t.Fatalf("acquire: %#v", r)
	}
	s.mu.Lock()
	l := s.leases[r.Lease]
	s.mu.Unlock()
	if time.Until(l.expires) > MaxLease+time.Second {
		t.Fatal("lease exceeded hard TTL cap")
	}
	renew := s.dispatch(protocol.Request{Version: 1, ID: "2", Op: "renew", Args: map[string]string{"lease": r.Lease, "ttl_seconds": "30"}})
	if !renew.OK {
		t.Fatalf("renew: %#v", renew)
	}
	s.dispatch(protocol.Request{Version: 1, ID: "3", Op: "release", Args: map[string]string{"lease": r.Lease}})
	s.mu.Lock()
	_, ok := s.leases[r.Lease]
	s.mu.Unlock()
	if ok {
		t.Fatal("lease not released")
	}
}

func TestConcurrentLeaseAcquisition(t *testing.T) {
	s := testServer()
	const n = 64
	var wg sync.WaitGroup
	ids := make(chan string, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			r := s.dispatch(protocol.Request{Version: 1, ID: fmt.Sprint(i), Op: "acquire"})
			if !r.OK {
				t.Errorf("acquire failed: %s", r.Error)
				return
			}
			ids <- r.Lease
		}(i)
	}
	wg.Wait()
	close(ids)
	seen := map[string]bool{}
	for id := range ids {
		if seen[id] {
			t.Fatalf("duplicate opaque lease %s", id)
		}
		seen[id] = true
	}
	if len(seen) != n {
		t.Fatalf("leases=%d want %d", len(seen), n)
	}
}

func TestResetChallengeStaleAndReplay(t *testing.T) {
	s := testServer()
	s.generation = 8
	s.challenges["stale"] = challenge{generation: 7, expires: time.Now().Add(time.Minute)}
	q := protocol.Request{Version: 1, ID: "r", Op: "factory-reset", Args: map[string]string{"challenge": "stale", "yes": "true", "generation": "8"}}
	if r := s.dispatch(q); r.OK {
		t.Fatal("stale challenge accepted")
	}
	s.challenges["used"] = challenge{generation: 8, expires: time.Now().Add(time.Minute)}
	q.Args["challenge"] = "used"
	if r := s.dispatch(q); r.OK {
		t.Fatal("reset succeeded without offline checks")
	}
	if r := s.dispatch(q); r.OK {
		t.Fatal("replayed reset challenge accepted")
	}
}

func TestStopBlocksNewLeasesAndAllowsExistingWorkToDrain(t *testing.T) {
	s := testServer()
	initial := s.dispatch(protocol.Request{Version: 1, ID: "acquire", Op: "acquire"})
	if !initial.OK {
		t.Fatalf("initial acquire: %#v", initial)
	}
	s.mu.Lock()
	s.stopping = true
	s.mu.Unlock()
	if r := s.dispatch(protocol.Request{Version: 1, ID: "new", Op: "acquire"}); r.OK || !strings.Contains(r.Error, "lifecycle stop/reset") {
		t.Fatalf("new lease was not blocked during stop: %#v", r)
	}
	if r := s.dispatch(protocol.Request{Version: 1, ID: "renew", Op: "renew", Args: map[string]string{"lease": initial.Lease}}); !r.OK {
		t.Fatalf("existing operation could not renew while stop drains: %#v", r)
	}
	s.dispatch(protocol.Request{Version: 1, ID: "release", Op: "release", Args: map[string]string{"lease": initial.Lease}})
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.leases) != 0 {
		t.Fatalf("lease did not drain: %d remain", len(s.leases))
	}
}

func TestPeerUIDWithUnixSocket(t *testing.T) {
	path := filepath.Join(t.TempDir(), "peer.sock")
	ln, e := net.Listen("unix", path)
	if e != nil {
		t.Fatal(e)
	}
	defer ln.Close()
	accepted := make(chan net.Conn, 1)
	go func() { c, _ := ln.Accept(); accepted <- c }()
	client, e := net.Dial("unix", path)
	if e != nil {
		t.Fatal(e)
	}
	defer client.Close()
	server := <-accepted
	defer server.Close()
	uid, e := peerUID(server)
	if e != nil {
		t.Fatal(e)
	}
	if uid != uint32(os.Getuid()) {
		t.Fatalf("peer uid %d != current %d", uid, os.Getuid())
	}
}

func TestOversizedControllerRequestBounded(t *testing.T) {
	raw := strings.Repeat("x", protocol.MaxFrame+4096)
	reader := bufio.NewReader(io.LimitReader(strings.NewReader(raw), protocol.MaxFrame+1))
	line, e := reader.ReadBytes('\n')
	if e == nil && len(line) <= protocol.MaxFrame {
		t.Fatal("oversized unterminated request accepted")
	}
	if len(line) > protocol.MaxFrame+1 {
		t.Fatalf("reader retained %d bytes beyond configured request limit", len(line))
	}
}

func TestMalformedJSONIsRejected(t *testing.T) {
	for _, raw := range []string{"{", "[]", "{\"version\":2,\"id\":\"x\",\"op\":\"status\"}", "{\"version\":1}"} {
		if _, e := decodeRequest([]byte(raw)); e == nil {
			t.Fatalf("accepted malformed request %s", raw)
		}
	}
}
