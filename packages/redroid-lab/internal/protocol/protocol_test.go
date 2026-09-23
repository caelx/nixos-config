package protocol

import (
	"bytes"
	"encoding/binary"
	"testing"
)

func TestFrameRoundTrip(t *testing.T) {
	var b bytes.Buffer
	want := StreamFrame{Version: Version, Type: "stdin", Data: []byte("hello")}
	if err := WriteFrame(&b, want); err != nil {
		t.Fatal(err)
	}
	var got StreamFrame
	if err := ReadFrame(&b, &got); err != nil {
		t.Fatal(err)
	}
	if got.Type != want.Type || string(got.Data) != string(want.Data) {
		t.Fatalf("got %#v", got)
	}
}

func TestReadFrameRejectsZeroAndOversize(t *testing.T) {
	for _, n := range []uint32{0, MaxFrame + 1} {
		var b bytes.Buffer
		_ = binary.Write(&b, binary.BigEndian, n)
		var out StreamFrame
		if err := ReadFrame(&b, &out); err == nil {
			t.Fatalf("accepted frame size %d", n)
		}
	}
}

func TestReadFrameRejectsTruncatedHeaderAndPayload(t *testing.T) {
	for _, raw := range [][]byte{{0, 0}, {0, 0, 0, 2, '{'}} {
		var out StreamFrame
		if err := ReadFrame(bytes.NewReader(raw), &out); err == nil {
			t.Fatal("accepted truncated frame")
		}
	}
}
