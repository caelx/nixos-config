package control

import (
	"errors"
	"testing"
	"time"
)

func TestWaitGuestReadyRetriesTransientUnavailableGuest(t *testing.T) {
	attempts := 0
	err := waitGuestReadyWith(5*time.Second, func(seconds int) error {
		attempts++
		if seconds < 1 || seconds > 180 {
			t.Fatalf("invalid guest readiness timeout: %d", seconds)
		}
		if attempts < 3 {
			return errors.New("connection refused")
		}
		return nil
	}, func(time.Duration) {})
	if err != nil {
		t.Fatal(err)
	}
	if attempts != 3 {
		t.Fatalf("made %d readiness attempts, want 3", attempts)
	}
}
