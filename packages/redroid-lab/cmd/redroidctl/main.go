package main

import (
	"bufio"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"ghostship.local/redroid-lab/internal/protocol"
)

const gatewayURL = "https://redroid-gateway:8787"
const tokenPath = "/home/t3code/.config/redroid/gateway-token"
const caPath = "/home/t3code/.config/redroid/gateway-ca.crt"
const usage = "usage: redroidctl status|start|stop|restart|wait|logs|keepalive|factory-reset|adb|shell|install|uninstall|launch|stop-app|screenshot|screenrecord|logcat|pull|push"

func die(e error) { fmt.Fprintln(os.Stderr, "redroidctl:", e); os.Exit(1) }
func main() {
	if len(os.Args) < 2 {
		die(errors.New(usage))
	}
	cmd := os.Args[1]
	if cmd == "help" || cmd == "--help" || cmd == "-h" {
		fmt.Println(usage)
		return
	}
	args := os.Args[2:]
	if cmd == "adb" {
		if len(args) == 0 {
			die(errors.New("adb requires arguments"))
		}
		var input io.Reader
		if args[0] == "shell" {
			input = shellInput(args[1:])
		}
		if e := stream("adb", args, input); e != nil {
			die(e)
		}
		return
	}
	if cmd == "shell" || cmd == "install" || cmd == "uninstall" || cmd == "launch" || cmd == "stop-app" || cmd == "screenshot" || cmd == "screenrecord" || cmd == "logcat" || cmd == "pull" || cmd == "push" {
		if cmd == "install" {
			if len(args) != 1 {
				die(errors.New("install requires one local APK path"))
			}
			f, e := os.Open(args[0])
			if e != nil {
				die(e)
			}
			defer f.Close()
			if e = stream("install", nil, f); e != nil {
				die(e)
			}
			return
		}
		if cmd == "pull" {
			if len(args) != 2 {
				die(errors.New("pull requires remote path and local output path"))
			}
			if e := stream("pull", args, nil); e != nil {
				die(e)
			}
			return
		}
		if cmd == "push" {
			if len(args) != 2 {
				die(errors.New("push requires local input path and remote path"))
			}
			f, e := os.Open(args[0])
			if e != nil {
				die(e)
			}
			defer f.Close()
			if e = stream("push", []string{args[1]}, f); e != nil {
				die(e)
			}
			return
		}
		if cmd == "screenshot" {
			if len(args) != 1 {
				die(errors.New("screenshot requires output path"))
			}
			if e := stream("screenshot", args, nil); e != nil {
				die(e)
			}
			return
		}
		var input io.Reader
		if cmd == "shell" {
			input = shellInput(args)
		}
		if e := stream(cmd, args, input); e != nil {
			die(e)
		}
		return
	}
	q := protocol.Request{Version: protocol.Version, ID: "cli", Op: cmd, Args: map[string]string{}}
	if cmd == "factory-reset" {
		yes := false
		for _, v := range args {
			if v == "--yes" {
				yes = true
			}
		}
		if !yes {
			st, _ := os.Stdin.Stat()
			if st == nil || st.Mode()&os.ModeCharDevice == 0 {
				die(errors.New("factory-reset is destructive; pass --yes for non-interactive use"))
			}
			fmt.Fprint(os.Stderr, "This permanently resets Android /data. Type RESET to continue: ")
			answer, err := bufio.NewReader(os.Stdin).ReadString('\n')
			if err != nil || strings.TrimSpace(answer) != "RESET" {
				die(errors.New("factory reset cancelled"))
			}
		}
		ch, e := rpc(protocol.Request{Version: 1, ID: "challenge", Op: "reset-challenge"})
		if e != nil {
			die(e)
		}
		q.Args["challenge"] = ch.Lease
		q.Args["yes"] = "true"
		q.Args["generation"] = fmt.Sprint(ch.Generation)
	}
	r, e := rpc(q)
	if e != nil {
		die(e)
	}
	if !r.OK {
		die(errors.New(r.Error))
	}
	if cmd == "start" || cmd == "restart" {
		root, err := rpc(protocol.Request{Version: protocol.Version, ID: "root-check", Op: "verify-ready"})
		if err != nil {
			die(err)
		}
		if !root.OK {
			die(fmt.Errorf("Android base is ready, but full root validation is pending: %s; install and launch the pinned KernelSU Manager, then run redroidctl wait", root.Error))
		}
	}
	if len(r.Data) > 0 {
		if cmd == "logs" {
			var value struct {
				Logs string `json:"logs"`
			}
			if json.Unmarshal(r.Data, &value) == nil {
				fmt.Print(value.Logs)
				return
			}
		}
		var pretty any
		if json.Unmarshal(r.Data, &pretty) == nil {
			b, _ := json.MarshalIndent(pretty, "", "  ")
			fmt.Println(string(b))
		} else {
			fmt.Println(string(r.Data))
		}
	} else {
		fmt.Println("OK")
	}
}

func shellInput(args []string) io.Reader {
	info, err := os.Stdin.Stat()
	if err == nil && info.Mode()&os.ModeCharDevice != 0 && len(args) > 0 {
		// A one-shot shell command should receive EOF unless the caller pipes
		// input explicitly. Keep a terminal attached for an interactive shell.
		return nil
	}
	return os.Stdin
}

func tlsConfig() (*tls.Config, string, error) {
	tokenFile := os.Getenv("REDROID_GATEWAY_TOKEN_FILE")
	if tokenFile == "" {
		tokenFile = tokenPath
	}
	caFile := os.Getenv("REDROID_GATEWAY_CA_FILE")
	if caFile == "" {
		caFile = caPath
	}
	token, e := os.ReadFile(tokenFile)
	if e != nil {
		return nil, "", e
	}
	ca, e := os.ReadFile(caFile)
	if e != nil {
		return nil, "", e
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(ca) {
		return nil, "", errors.New("invalid gateway CA")
	}
	return &tls.Config{MinVersion: tls.VersionTLS13, RootCAs: pool, ServerName: "redroid-gateway"}, strings.TrimSpace(string(token)), nil
}
func rpc(q protocol.Request) (protocol.Response, error) {
	cfg, token, e := tlsConfig()
	if e != nil {
		return protocol.Response{}, e
	}
	body, _ := json.Marshal(q)
	req, e := httpNewPost(gatewayURL+"/rpc", body, token)
	if e != nil {
		return protocol.Response{}, e
	}
	c := &http.Client{Transport: &http.Transport{TLSClientConfig: cfg}}
	resp, e := c.Do(req)
	if e != nil {
		return protocol.Response{}, e
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return protocol.Response{}, fmt.Errorf("gateway HTTP %s", resp.Status)
	}
	var r protocol.Response
	e = json.NewDecoder(io.LimitReader(resp.Body, protocol.MaxFrame)).Decode(&r)
	return r, e
}
func httpNewPost(u string, b []byte, t string) (*http.Request, error) {
	req, e := http.NewRequest("POST", u, strings.NewReader(string(b)))
	if e != nil {
		return nil, e
	}
	req.Header.Set("Authorization", "Bearer "+t)
	req.Header.Set("Content-Type", "application/json")
	return req, nil
}
func stream(op string, args []string, input io.Reader) error {
	cfg, token, e := tlsConfig()
	if e != nil {
		return e
	}
	conn, e := tls.Dial("tcp", "redroid-gateway:8787", cfg)
	if e != nil {
		return e
	}
	defer conn.Close()
	fmt.Fprintf(conn, "POST /session HTTP/1.1\r\nHost: redroid-gateway:8787\r\nAuthorization: Bearer %s\r\nContent-Length: 0\r\n\r\n", token)
	br := bufio.NewReader(conn)
	hreq, _ := http.NewRequest("POST", "https://redroid-gateway:8787/session", nil)
	res, e := http.ReadResponse(br, hreq)
	if e != nil {
		return e
	}
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("session request failed: %s", res.Status)
	}
	var pair struct {
		Nonce   string `json:"nonce"`
		Session string `json:"session"`
	}
	if e = json.NewDecoder(io.LimitReader(res.Body, 4096)).Decode(&pair); e != nil {
		res.Body.Close()
		return e
	}
	res.Body.Close()
	fmt.Fprintf(conn, "CONNECT /adb HTTP/1.1\r\nHost: redroid-gateway:8787\r\nAuthorization: Bearer %s\r\nX-Redroid-Nonce: %s\r\n\r\n", token, pair.Nonce)
	resp, e := httpReadHead(br)
	if e != nil {
		return e
	}
	if !strings.Contains(resp, "200") {
		return fmt.Errorf("gateway CONNECT failed: %s", strings.TrimSpace(resp))
	}
	rw := bufio.NewReadWriter(br, bufio.NewWriter(conn))
	if e = writeFrame(rw, protocol.StreamFrame{Version: 1, Type: "hello", Nonce: pair.Nonce, Session: pair.Session}); e != nil {
		return e
	}
	if e = writeFrame(rw, protocol.StreamFrame{Version: 1, Type: "exec", Op: op, Args: args}); e != nil {
		return e
	}
	var inputDone chan error
	if input != nil {
		frameType, eofType := "stdin", "stdin-eof"
		if op == "install" || op == "push" {
			frameType, eofType = "upload", "upload-eof"
		}
		inputDone = make(chan error, 1)
		go func() {
			buf := make([]byte, 24<<10)
			for {
				n, er := input.Read(buf)
				if n > 0 {
					if err := writeFrame(rw, protocol.StreamFrame{Version: 1, Type: frameType, Data: append([]byte(nil), buf[:n]...)}); err != nil {
						inputDone <- err
						return
					}
				}
				if er == io.EOF {
					inputDone <- writeFrame(rw, protocol.StreamFrame{Version: 1, Type: eofType})
					return
				}
				if er != nil {
					inputDone <- er
					return
				}
			}
		}()
	} else {
		_ = writeFrame(rw, protocol.StreamFrame{Version: 1, Type: "stdin-eof"})
	}
	var outputFile *os.File
	for {
		f := protocol.StreamFrame{}
		if e = protocol.ReadFrame(rw, &f); e != nil {
			return e
		}
		switch f.Type {
		case "stdout":
			if op == "screenshot" && len(args) > 0 || op == "pull" && len(args) > 1 {
				if outputFile == nil {
					path := args[0]
					if op == "pull" {
						path = args[1]
					}
					outputFile, e = os.OpenFile(path, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0600)
					if e != nil {
						return e
					}
					if e = outputFile.Chmod(0600); e != nil {
						outputFile.Close()
						return e
					}
				}
				if _, e = outputFile.Write(f.Data); e != nil {
					return e
				}
			} else if _, e = os.Stdout.Write(f.Data); e != nil {
				return e
			}
		case "stderr":
			_, _ = os.Stderr.Write(f.Data)
		case "error":
			return errors.New(string(f.Data))
		case "exit":
			if outputFile != nil {
				if e = outputFile.Sync(); e != nil {
					outputFile.Close()
					return e
				}
				if e = outputFile.Close(); e != nil {
					return e
				}
			}
			if inputDone != nil {
				select {
				case inputErr := <-inputDone:
					if inputErr != nil {
						return inputErr
					}
				default:
				}
			}
			return nil
		}
	}
}
func httpReadHead(br *bufio.Reader) (string, error) {
	line, e := br.ReadString('\n')
	if e != nil {
		return "", e
	}
	var b strings.Builder
	b.WriteString(line)
	for {
		line, e = br.ReadString('\n')
		if e != nil {
			return "", e
		}
		if line == "\r\n" {
			break
		}
		b.WriteString(line)
	}
	return b.String(), nil
}

func writeFrame(w *bufio.ReadWriter, f protocol.StreamFrame) error {
	if e := protocol.WriteFrame(w, f); e != nil {
		return e
	}
	return w.Flush()
}
