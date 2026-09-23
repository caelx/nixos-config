package gateway

import (
	"bufio"
	"context"
	"crypto/rand"
	"crypto/subtle"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	"ghostship.local/redroid-lab/internal/control"
	"ghostship.local/redroid-lab/internal/protocol"
)

const endpoint = ":8787"
const tokenFile = "/run/secrets/redroid-gateway-token"
const certFile = "/run/secrets/tls.crt"
const keyFile = "/run/secrets/tls.key"

var adbPath = "/run/current-system/sw/bin/adb"

const adbSocket = "localfilesystem:/run/redroid/adb.sock"
const adbDevice = "vsock:77:5555"

type nonce struct {
	session string
	expires time.Time
}
type Server struct {
	token  string
	mu     sync.Mutex
	nonces map[string]nonce
}

func New() *Server { return &Server{nonces: map[string]nonce{}} }
func (s *Server) Serve() error {
	b, e := os.ReadFile(tokenFile)
	if e != nil {
		return e
	}
	s.token = strings.TrimSpace(string(b))
	if len(s.token) < 32 {
		return errors.New("gateway token must be at least 32 bytes")
	}
	cert, e := tls.LoadX509KeyPair(certFile, keyFile)
	if e != nil {
		return e
	}
	srv := &http.Server{Addr: endpoint, Handler: s, ReadHeaderTimeout: 10 * time.Second, MaxHeaderBytes: 16 << 10, TLSConfig: &tls.Config{MinVersion: tls.VersionTLS13, Certificates: []tls.Certificate{cert}}}
	return srv.ListenAndServeTLS("", "")
}
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if !s.auth(r) {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	switch {
	case r.Method == http.MethodPost && r.URL.Path == "/rpc":
		s.rpc(w, r)
	case r.Method == http.MethodPost && r.URL.Path == "/session":
		s.newSession(w)
	case r.Method == http.MethodConnect && r.URL.Path == "/adb":
		s.connect(w, r)
	default:
		http.NotFound(w, r)
	}
}
func (s *Server) auth(r *http.Request) bool {
	v := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	return len(v) == len(s.token) && subtle.ConstantTimeCompare([]byte(v), []byte(s.token)) == 1
}
func id() (string, error) {
	b := make([]byte, 24)
	if _, e := rand.Read(b); e != nil {
		return "", e
	}
	return hex.EncodeToString(b), nil
}
func (s *Server) newSession(w http.ResponseWriter) {
	n, e := id()
	if e != nil {
		http.Error(w, "random failure", 500)
		return
	}
	sid, e := id()
	if e != nil {
		http.Error(w, "random failure", 500)
		return
	}
	s.mu.Lock()
	s.prune()
	if len(s.nonces) >= 128 {
		s.mu.Unlock()
		http.Error(w, "too many pending ADB sessions", http.StatusTooManyRequests)
		return
	}
	s.nonces[n] = nonce{sid, time.Now().Add(30 * time.Second)}
	s.mu.Unlock()
	writeJSON(w, map[string]string{"nonce": n, "session": sid})
}
func (s *Server) prune() {
	now := time.Now()
	for k, v := range s.nonces {
		if !v.expires.After(now) {
			delete(s.nonces, k)
		}
	}
}
func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}
func (s *Server) rpc(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, protocol.MaxFrame)
	defer r.Body.Close()
	var q protocol.Request
	d := json.NewDecoder(r.Body)
	d.DisallowUnknownFields()
	if e := d.Decode(&q); e != nil {
		http.Error(w, "invalid request", 400)
		return
	}
	var extra any
	if e := d.Decode(&extra); e != io.EOF {
		http.Error(w, "trailing or malformed JSON", 400)
		return
	}
	if q.Version != protocol.Version || q.ID == "" || len(q.Args) > 24 {
		http.Error(w, "invalid protocol request", 400)
		return
	}
	for k, v := range q.Args {
		if len(k) > 128 || len(v) > 8192 {
			http.Error(w, "argument too long", 400)
			return
		}
	}
	res, e := dispatch(q)
	if e != nil {
		res = protocol.Response{Version: protocol.Version, ID: q.ID, OK: false, Error: e.Error()}
	}
	res.ID = q.ID
	writeJSON(w, res)
}
func dispatch(q protocol.Request) (protocol.Response, error) {
	if q.Op == "adb" {
		return adbRPC(q)
	}
	if !oneOf(q.Op, "status", "start", "stop", "restart", "wait", "verify-ready", "logs", "keepalive", "reset-challenge", "factory-reset", "acquire", "renew", "release") {
		return protocol.Response{}, errors.New("unsupported operation")
	}
	if q.Op == "wait" || q.Op == "logs" || q.Op == "verify-ready" {
		var result protocol.Response
		e := withLease(func(_ context.Context, _ string) error {
			var callErr error
			result, callErr = controller(q.Op, q.Args)
			return callErr
		})
		if e != nil {
			return result, e
		}
		return result, nil
	}
	res, e := control.Call(q)
	if e != nil {
		return res, e
	}
	if !res.OK {
		return res, errors.New(res.Error)
	}
	return res, nil
}
func oneOf(s string, vs ...string) bool {
	for _, v := range vs {
		if s == v {
			return true
		}
	}
	return false
}
func adbArgs(a []string) ([]string, error) {
	if len(a) == 0 || len(a) > 64 {
		return nil, errors.New("invalid adb argument list")
	}
	bad := map[string]bool{"-H": true, "-P": true, "-L": true, "-s": true, "-t": true, "-d": true, "-e": true, "-a": true, "server": true, "start-server": true, "kill-server": true, "connect": true, "disconnect": true, " nodaemon server": true}
	if bad[a[0]] || strings.HasPrefix(a[0], "-") {
		return nil, errors.New("ADB server, socket, device and server lifecycle are fixed by policy")
	}
	if a[0] == "install" || a[0] == "push" || a[0] == "pull" {
		return nil, errors.New("use redroidctl install, push, or pull for bounded file transfer")
	}
	for _, v := range a {
		if len(v) > 4096 || strings.ContainsRune(v, 0) {
			return nil, errors.New("invalid adb argument")
		}
	}
	return append([]string{"-L", adbSocket, "-s", adbDevice}, a...), nil
}
func transferADBArgs(a []string) ([]string, error) {
	if len(a) == 0 || len(a) > 64 || !oneOf(a[0], "install", "push", "pull") {
		return nil, errors.New("invalid ADB file-transfer operation")
	}
	for _, v := range a {
		if len(v) > 4096 || strings.ContainsRune(v, 0) {
			return nil, errors.New("invalid ADB transfer argument")
		}
	}
	return append([]string{"-L", adbSocket, "-s", adbDevice}, a...), nil
}
func controller(op string, args map[string]string) (protocol.Response, error) {
	q := protocol.Request{Version: protocol.Version, ID: "gateway", Op: op, Args: args}
	r, e := control.Call(q)
	if e != nil {
		return r, e
	}
	if !r.OK {
		return r, errors.New(r.Error)
	}
	return r, nil
}
func withLease(run func(context.Context, string) error) error {
	r, e := controller("acquire", map[string]string{"ttl_seconds": "45"})
	if e != nil {
		return e
	}
	lease := r.Lease
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, 1)
	go func() {
		t := time.NewTicker(15 * time.Second)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				done <- nil
				return
			case <-t.C:
				if _, e := controller("renew", map[string]string{"lease": lease, "ttl_seconds": "45"}); e != nil {
					cancel()
					done <- e
					return
				}
			}
		}
	}()
	runErr := error(nil)
	if _, e = controller("start", map[string]string{"lease": lease}); e != nil {
		runErr = fmt.Errorf("start/wait for Android: %w", e)
	} else if ctx.Err() != nil {
		runErr = ctx.Err()
	} else {
		runErr = run(ctx, lease)
	}
	cancel()
	renewErr := <-done
	_, releaseErr := controller("release", map[string]string{"lease": lease})
	if renewErr != nil {
		return fmt.Errorf("operation lease expired; child context canceled: %w", renewErr)
	}
	if runErr != nil {
		return runErr
	}
	return releaseErr
}
func adbRPC(q protocol.Request) (protocol.Response, error) {
	var requested []string
	if e := json.Unmarshal([]byte(q.Args["argv"]), &requested); e != nil {
		return protocol.Response{}, errors.New("adb argv must be a JSON string array")
	}
	args, e := adbArgs(requested)
	if e != nil {
		return protocol.Response{}, e
	}
	var out []byte
	e = withLease(func(ctx context.Context, _ string) error {
		cmd := exec.CommandContext(ctx, adbPath, args...)
		var x error
		out, x = cmd.CombinedOutput()
		return x
	})
	res := protocol.Response{Version: protocol.Version, ID: q.ID, OK: e == nil}
	if e != nil {
		res.Error = e.Error()
	}
	if len(out) > protocol.MaxFrame/2 {
		out = out[:128<<10]
	}
	res.Data, _ = json.Marshal(map[string]string{"output": string(out)})
	return res, e
}
func (s *Server) connect(w http.ResponseWriter, r *http.Request) {
	n := r.Header.Get("X-Redroid-Nonce")
	sess, ok := s.consumeNonce(n)
	if !ok {
		http.Error(w, "invalid or replayed nonce", 401)
		return
	}
	hj, ok := w.(http.Hijacker)
	if !ok {
		http.Error(w, "CONNECT unsupported", 500)
		return
	}
	conn, rw, e := hj.Hijack()
	if e != nil {
		return
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(30 * time.Second))
	_, _ = rw.WriteString("HTTP/1.1 200 Connection Established\r\n\r\n")
	_ = rw.Flush()
	fr := protocol.StreamFrame{}
	if e = protocol.ReadFrame(rw, &fr); e != nil || fr.Version != protocol.Version || fr.Type != "hello" || fr.Nonce != n || fr.Session != sess.session {
		return
	}
	req := protocol.StreamFrame{}
	if e = protocol.ReadFrame(rw, &req); e != nil || req.Version != protocol.Version || req.Type != "exec" {
		return
	}
	_ = conn.SetDeadline(time.Time{})
	e = withLease(func(ctx context.Context, _ string) error {
		watchDone := make(chan struct{})
		go func() {
			select {
			case <-ctx.Done():
				_ = conn.SetReadDeadline(time.Now())
			case <-watchDone:
			}
		}()
		err := executeStream(ctx, conn, rw, req)
		close(watchDone)
		return err
	})
	if e != nil {
		_ = protocol.WriteFrame(rw, protocol.StreamFrame{Version: 1, Type: "error", Data: []byte(e.Error())})
		_ = rw.Flush()
	}
}

func executeStream(ctx context.Context, conn net.Conn, rw *bufio.ReadWriter, req protocol.StreamFrame) error {
	args, e := streamArgs(req.Op, req.Args)
	if e != nil {
		return e
	}
	var temp string
	if req.Op == "install" || req.Op == "push" {
		if req.Op == "install" && len(req.Args) != 0 || req.Op == "push" && len(req.Args) != 1 {
			return errors.New("invalid upload arguments")
		}
		var file *os.File
		file, e = os.CreateTemp("/tmp", "redroid-upload-*.apk")
		if e != nil {
			return errors.New("cannot create private upload file")
		}
		temp = file.Name()
		defer os.Remove(temp)
		if e = receiveUpload(rw, file); e != nil {
			file.Close()
			return e
		}
		if e = file.Sync(); e != nil {
			file.Close()
			return e
		}
		if e = file.Close(); e != nil {
			return e
		}
		if req.Op == "install" {
			args, e = transferADBArgs([]string{"install", temp})
		} else {
			args, e = transferADBArgs([]string{"push", temp, req.Args[0]})
		}
		if e != nil {
			return e
		}
	}
	if req.Op == "pull" {
		if len(req.Args) != 2 {
			return errors.New("pull requires remote and output name")
		}
		file, er := os.CreateTemp("/tmp", "redroid-download-*")
		if er != nil {
			return er
		}
		temp = file.Name()
		file.Close()
		defer os.Remove(temp)
		args, e = transferADBArgs([]string{"pull", req.Args[0], temp})
		if e != nil {
			return e
		}
		out, er := exec.CommandContext(ctx, adbPath, args...).CombinedOutput()
		if er != nil {
			return fmt.Errorf("adb pull failed: %s", strings.TrimSpace(string(out)))
		}
		if e == nil {
			e = sendFile(rw, temp)
		}
	} else {
		e = streamADB(ctx, conn, rw, args)
	}
	return e
}

func (s *Server) consumeNonce(n string) (nonce, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.prune()
	v, ok := s.nonces[n]
	delete(s.nonces, n)
	return v, ok
}

const maxTransfer = 512 << 20

func receiveUpload(r io.Reader, f *os.File) error {
	total := 0
	for {
		fr := protocol.StreamFrame{}
		if e := protocol.ReadFrame(r, &fr); e != nil {
			return e
		}
		if fr.Version != protocol.Version {
			return errors.New("invalid upload frame version")
		}
		switch fr.Type {
		case "upload-eof":
			return nil
		case "upload":
			total += len(fr.Data)
			if total > maxTransfer {
				return errors.New("upload exceeds 512 MiB limit")
			}
			if _, e := f.Write(fr.Data); e != nil {
				return e
			}
		default:
			return errors.New("expected upload frame")
		}
	}
}
func sendFile(w io.Writer, path string) error {
	f, e := os.Open(path)
	if e != nil {
		return e
	}
	defer f.Close()
	b := make([]byte, 24<<10)
	for {
		n, er := f.Read(b)
		if n > 0 {
			if e = protocol.WriteFrame(w, protocol.StreamFrame{Version: 1, Type: "stdout", Data: append([]byte(nil), b[:n]...)}); e != nil {
				return e
			}
			if f, ok := w.(interface{ Flush() error }); ok {
				if e = f.Flush(); e != nil {
					return e
				}
			}
		}
		if er == io.EOF {
			break
		}
		if er != nil {
			return er
		}
	}
	if e = protocol.WriteFrame(w, protocol.StreamFrame{Version: 1, Type: "exit"}); e != nil {
		return e
	}
	if f, ok := w.(interface{ Flush() error }); ok {
		return f.Flush()
	}
	return nil
}
func streamArgs(op string, args []string) ([]string, error) {
	switch op {
	case "adb":
		return adbArgs(args)
	case "shell", "install", "uninstall", "launch", "stop-app", "screenshot", "screenrecord", "logcat", "pull", "push":
		if len(args) > 64 {
			return nil, errors.New("too many ADB arguments")
		}
		a := []string{}
		switch op {
		case "shell":
			a = append(a, "shell")
		case "install":
			a = append(a, "install")
		case "uninstall":
			a = append(a, "uninstall")
		case "launch":
			a = append(a, "shell", "monkey", "-p")
		case "stop-app":
			a = append(a, "shell", "am", "force-stop")
		case "screenshot":
			a = append(a, "exec-out", "screencap", "-p")
		case "screenrecord":
			a = append(a, "shell", "screenrecord")
		case "logcat":
			a = append(a, "logcat")
		case "pull":
			a = append(a, "pull")
		case "push":
			a = append(a, "push")
		}
		if op == "screenshot" && len(args) != 1 {
			return nil, errors.New("screenshot requires one local output name")
		}
		if op == "screenshot" {
			args = nil
		}
		for _, v := range args {
			if len(v) > 4096 || strings.ContainsRune(v, 0) {
				return nil, errors.New("invalid argument")
			}
		}
		full := append(append([]string{"-L", adbSocket, "-s", adbDevice}, a...), args...)
		if op == "launch" {
			full = append(full, "1")
		}
		return full, nil
	default:
		return nil, errors.New("unsupported stream operation")
	}
}

type lockedWriter struct {
	mu sync.Mutex
	w  io.Writer
}

func (l *lockedWriter) frame(f protocol.StreamFrame) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if e := protocol.WriteFrame(l.w, f); e != nil {
		return e
	}
	if w, ok := l.w.(interface{ Flush() error }); ok {
		return w.Flush()
	}
	return nil
}
func streamADB(ctx context.Context, conn net.Conn, rw *bufio.ReadWriter, args []string) error {
	cmdCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	cmd := exec.CommandContext(cmdCtx, adbPath, args...)
	stdin, e := cmd.StdinPipe()
	if e != nil {
		return e
	}
	writer := &lockedWriter{w: rw}
	outputErr := make(chan error, 1)
	var outputErrOnce sync.Once
	output := func(typ string) io.Writer {
		return frameOutput{typ: typ, writer: writer, onError: func(err error) {
			outputErrOnce.Do(func() {
				outputErr <- err
				cancel()
			})
		}}
	}
	cmd.Stdout = output("stdout")
	cmd.Stderr = output("stderr")
	if e = cmd.Start(); e != nil {
		return e
	}
	disconnected := make(chan struct{})
	go func() {
		defer close(disconnected)
		stdinClosed := false
		for {
			f := protocol.StreamFrame{}
			if protocol.ReadFrame(rw, &f) != nil {
				return
			}
			if f.Version != protocol.Version {
				return
			}
			if f.Type == "stdin-eof" {
				if !stdinClosed {
					_ = stdin.Close()
					stdinClosed = true
				}
				continue
			}
			if f.Type != "stdin" || stdinClosed {
				return
			}
			if _, e := stdin.Write(f.Data); e != nil {
				return
			}
		}
	}()
	wait := make(chan error, 1)
	go func() { wait <- cmd.Wait() }()
	select {
	case e = <-wait:
	case <-ctx.Done():
		_ = cmd.Process.Kill()
		e = <-wait
	case <-disconnected:
		cancel()
		_ = cmd.Process.Kill()
		e = <-wait
	case e = <-outputErr:
		_ = cmd.Process.Kill()
		<-wait
		return e
	}
	_ = conn.SetDeadline(time.Now().Add(time.Second))
	if e != nil {
		return e
	}
	return writer.frame(protocol.StreamFrame{Version: 1, Type: "exit"})
}

type frameOutput struct {
	typ     string
	writer  *lockedWriter
	onError func(error)
}

func (o frameOutput) Write(p []byte) (int, error) {
	written := 0
	for len(p) > 0 {
		n := len(p)
		if n > 24<<10 {
			n = 24 << 10
		}
		if err := o.writer.frame(protocol.StreamFrame{Version: protocol.Version, Type: o.typ, Data: append([]byte(nil), p[:n]...)}); err != nil {
			o.onError(err)
			return written, err
		}
		written += n
		p = p[n:]
	}
	return written, nil
}
