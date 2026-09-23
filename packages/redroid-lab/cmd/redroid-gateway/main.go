package main

import (
	"fmt"
	"ghostship.local/redroid-lab/internal/gateway"
	"os"
)

func main() {
	if e := gateway.New().Serve(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
