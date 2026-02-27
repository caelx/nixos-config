# Implementation Plan: Windows Notifications for WSL2

This plan outlines the steps to implement a Windows notification bridge for WSL2, including a utility script and Fish shell hooks for automatic alerts.

## Phase 1: Notification Utility
- [x] Task: Create the `win-notify` script in `modules/common/wsl.nix`. d827a41
    - [ ] Implement PowerShell toast logic.
    - [ ] Ensure script is in path.
- [ ] Task: Conductor - User Manual Verification 'Notification Utility' (Protocol in workflow.md)

## Phase 2: Fish Shell Hooks
- [ ] Task: Implement command completion notification.
- [ ] Task: Implement 'Action Required' and 'Ready' title monitoring.
- [ ] Task: Implement Sudo password prompt detection.
- [ ] Task: Implement 'Long Task' notification (3+ minutes).
    - [ ] Add a background timer or check in Fish for tasks exceeding 3 minutes.
- [ ] Task: Implement "High Demand" message detection.
    - [ ] Use Fish hooks or a background process to detect the specific message.
- [ ] Task: Conductor - User Manual Verification 'Fish Shell Hooks' (Protocol in workflow.md)

## Phase 3: Integration & Cleanup
- [ ] Task: Final integration and configuration options.
- [ ] Task: Conductor - User Manual Verification 'Integration & Cleanup' (Protocol in workflow.md)
