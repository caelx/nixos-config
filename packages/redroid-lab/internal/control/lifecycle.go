package control

import (
	"errors"
	"fmt"
	"os"
	"strings"
	"time"
)

const hostADB = "/run/current-system/sw/bin/adb"
const hostADBServer = "localfilesystem:/run/redroid/adb.sock"
const adbTarget = "vsock:77:5555"

func adb(args ...string) (string, error) {
	argv := append([]string{"-L", hostADBServer}, args...)
	return fixedOutput(hostADB, argv...)
}
func adbFor(args ...string) (string, error) {
	argv := append([]string{"-L", hostADBServer, "-s", adbTarget}, args...)
	return fixedOutput(hostADB, argv...)
}

func (s *Server) start() error {
	s.startMu.Lock()
	defer s.startMu.Unlock()
	active, e := unitActive()
	if e != nil {
		return e
	}
	if !active {
		if _, e = vmActiveAndExited(); e != nil {
			return e
		}
		if opened, openErr := diskOpen(); openErr != nil {
			return openErr
		} else if opened {
			return errors.New("Android data disk is still open by a process")
		}
		if e = recoverResetDisk(); e != nil {
			return fmt.Errorf("recover interrupted Android data reset: %w", e)
		}
		if e = run("/run/current-system/sw/bin/systemctl", "start", Unit); e != nil {
			return e
		}
	}
	s.mu.Lock()
	s.lastActivity = time.Now()
	s.mu.Unlock()
	if e = waitGuestReady(180 * time.Second); e != nil {
		return fmt.Errorf("guest readiness: %w", e)
	}
	publicKey, e := os.ReadFile("/var/lib/redroid/adb/.android/adbkey.pub")
	if e != nil {
		return fmt.Errorf("host ADB public key unavailable: %w", e)
	}
	if len(publicKey) > 4096 || strings.ContainsAny(string(publicKey), "\r\n") {
		return errors.New("host ADB public key has invalid format")
	}
	if _, e = guestCallWithKey("authorize-adb", 0, strings.TrimSpace(string(publicKey))); e != nil {
		return fmt.Errorf("authorize host ADB key: %w", e)
	}
	if _, e = adb("connect", adbTarget); e != nil {
		return fmt.Errorf("ADB VSOCK connect: %w", e)
	}
	deadline := time.Now().Add(30 * time.Second)
	for time.Now().Before(deadline) {
		state, er := adbFor("get-state")
		if er == nil && strings.TrimSpace(state) == "device" {
			break
		}
		time.Sleep(time.Second)
	}
	state, e := adbFor("get-state")
	if e != nil || strings.TrimSpace(state) != "device" {
		return errors.New("ADB VSOCK transport did not become device state")
	}
	root, rootErr := adbFor("shell", "id")
	if rootErr != nil || !strings.Contains(root, "uid=0(root)") {
		if _, e = adbFor("root"); e != nil {
			return fmt.Errorf("enable root ADB: %w", e)
		}
		_, _ = adbFor("wait-for-device")
	}
	boot, e := adbFor("shell", "getprop", "sys.boot_completed")
	if e != nil || strings.TrimSpace(boot) != "1" {
		return errors.New("Android sys.boot_completed is not 1")
	}
	if e = s.verifyRoot(); e != nil {
		return fmt.Errorf("Android booted but root acceptance failed: %w", e)
	}
	return nil
}

func waitGuestReady(timeout time.Duration) error {
	return waitGuestReadyWith(timeout, func(seconds int) error {
		_, err := guestCall("wait-ready", seconds)
		return err
	}, time.Sleep)
}

func waitGuestReadyWith(timeout time.Duration, wait func(int) error, pause func(time.Duration)) error {
	deadline := time.Now().Add(timeout)
	var lastErr error
	for {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			if lastErr != nil {
				return lastErr
			}
			return errors.New("guest readiness timed out")
		}
		seconds := int(remaining.Seconds())
		if seconds < 1 {
			seconds = 1
		}
		if seconds > 180 {
			seconds = 180
		}
		if err := wait(seconds); err == nil {
			return nil
		} else {
			lastErr = err
		}
		if time.Until(deadline) <= 0 {
			return lastErr
		}
		pause(time.Second)
	}
}

func (s *Server) verifyRoot() error {
	root, e := adbFor("shell", "id")
	if e != nil || !strings.Contains(root, "uid=0(root)") {
		return errors.New("root ADB validation failed")
	}
	su, e := adbFor("shell", "su", "-c", "id")
	if e != nil || !strings.Contains(su, "uid=0(root)") {
		return errors.New("KernelSU su validation failed")
	}
	return nil
}

func (s *Server) stopAndDrain(restart bool) error {
	s.mu.Lock()
	if s.stopping {
		s.mu.Unlock()
		return errors.New("stop already in progress")
	}
	s.stopping = true
	s.mu.Unlock()
	defer func() { s.mu.Lock(); s.stopping = false; s.mu.Unlock() }()
	return s.stopAndDrainClaimed(restart)
}

func (s *Server) stopAndDrainClaimed(restart bool) error {
	deadline := time.Now().Add(5 * time.Minute)
	for {
		s.mu.Lock()
		s.prune()
		busy := len(s.leases) > 0
		s.mu.Unlock()
		if !busy {
			break
		}
		if !time.Now().Before(deadline) {
			return errors.New("active analysis operations did not finish within five minutes; Android remains running")
		}
		time.Sleep(250 * time.Millisecond)
	}
	s.opMu.Lock()
	defer s.opMu.Unlock()
	if e := s.stopVM(); e != nil {
		return e
	}
	if restart {
		return s.start()
	}
	return nil
}

// stopClaimed performs a stop after the idle loop atomically set stopping
// under s.mu. Keepalive cannot succeed after that idle check.
func (s *Server) stopClaimed() error {
	defer func() { s.mu.Lock(); s.stopping = false; s.mu.Unlock() }()
	return s.stopVM()
}

func (s *Server) stopVM() error {
	active, e := unitActive()
	if e != nil {
		return e
	}
	if !active {
		return nil
	}
	if _, e = guestCall("shutdown", 0); e != nil {
		return fmt.Errorf("guest graceful shutdown failed; QEMU left running: %w", e)
	}
	if e = run("/run/current-system/sw/bin/systemctl", "stop", Unit); e != nil {
		return e
	}
	deadline := time.Now().Add(90 * time.Second)
	for time.Now().Before(deadline) {
		state, _ := fixedOutput("/run/current-system/sw/bin/systemctl", "is-active", Unit)
		pid, pe := fixedOutput("/run/current-system/sw/bin/systemctl", "show", "-p", "MainPID", "--value", Unit)
		if (strings.TrimSpace(state) == "inactive" || strings.TrimSpace(state) == "failed") && pe == nil && strings.TrimSpace(pid) == "0" {
			return nil
		}
		time.Sleep(500 * time.Millisecond)
	}
	return errors.New("MicroVM systemd unit/QEMU did not exit after graceful guest shutdown")
}

func (s *Server) idleLoop() {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		s.opMu.Lock()
		s.mu.Lock()
		s.prune()
		idle := len(s.leases) == 0 && !s.stopping && time.Since(s.lastActivity) >= s.idleTimeout
		if idle {
			s.stopping = true
		}
		s.mu.Unlock()
		if idle {
			_ = s.stopClaimed()
		}
		s.opMu.Unlock()
	}
}
