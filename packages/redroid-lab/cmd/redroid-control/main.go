package main

import (
	"fmt"
	"ghostship.local/redroid-lab/internal/control"
	"os"
)

func main() {
	if e := control.New().Serve(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
