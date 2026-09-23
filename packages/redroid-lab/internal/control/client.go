package control

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"time"

	"ghostship.local/redroid-lab/internal/protocol"
)

func Call(q protocol.Request) (protocol.Response, error) {
	c, err := net.DialTimeout("unix", SocketPath, 3*time.Second)
	if err != nil {
		return protocol.Response{}, err
	}
	defer c.Close()
	_ = c.SetDeadline(time.Now().Add(5 * time.Minute))
	b, err := json.Marshal(q)
	if err != nil {
		return protocol.Response{}, err
	}
	if len(b) > protocol.MaxFrame {
		return protocol.Response{}, fmt.Errorf("controller request too large")
	}
	if _, err = c.Write(append(b, '\n')); err != nil {
		return protocol.Response{}, err
	}
	line, err := bufio.NewReader(c).ReadBytes('\n')
	if err != nil {
		return protocol.Response{}, err
	}
	if len(line) > protocol.MaxFrame {
		return protocol.Response{}, fmt.Errorf("controller response too large")
	}
	var r protocol.Response
	if err = json.Unmarshal(line, &r); err != nil {
		return r, err
	}
	return r, nil
}
