package protocol

import (
	"encoding/json"
	"errors"
	"io"
)

const Version = 1
const MaxFrame = 1 << 20

type Request struct {
	Version int               `json:"version"`
	ID      string            `json:"id"`
	Op      string            `json:"op"`
	Args    map[string]string `json:"args,omitempty"`
}
type Response struct {
	Version    int             `json:"version"`
	ID         string          `json:"id,omitempty"`
	OK         bool            `json:"ok"`
	Error      string          `json:"error,omitempty"`
	Generation uint64          `json:"generation,omitempty"`
	Lease      string          `json:"lease,omitempty"`
	Data       json.RawMessage `json:"data,omitempty"`
}
type StreamFrame struct {
	Version int      `json:"version"`
	Type    string   `json:"type"`
	Nonce   string   `json:"nonce,omitempty"`
	Session string   `json:"session,omitempty"`
	Op      string   `json:"op,omitempty"`
	Args    []string `json:"args,omitempty"`
	Data    []byte   `json:"data,omitempty"`
}

func ReadFrame(r io.Reader, v any) error {
	var h [4]byte
	if _, e := io.ReadFull(r, h[:]); e != nil {
		return e
	}
	n := uint32(h[0])<<24 | uint32(h[1])<<16 | uint32(h[2])<<8 | uint32(h[3])
	if n == 0 || n > MaxFrame {
		return errors.New("invalid frame size")
	}
	b := make([]byte, n)
	if _, e := io.ReadFull(r, b); e != nil {
		return e
	}
	return json.Unmarshal(b, v)
}
func WriteFrame(w io.Writer, v any) error {
	b, e := json.Marshal(v)
	if e != nil {
		return e
	}
	if len(b) == 0 || len(b) > MaxFrame {
		return errors.New("invalid frame size")
	}
	n := uint32(len(b))
	h := [4]byte{byte(n >> 24), byte(n >> 16), byte(n >> 8), byte(n)}
	if _, e = w.Write(h[:]); e != nil {
		return e
	}
	_, e = w.Write(b)
	return e
}
