# Implementation Plan: Windows Notifications for WSL2

This plan outlines the steps to implement a Windows notification bridge for WSL2, including a utility script and Fish shell hooks for automatic alerts.

## Phase 1: Notification Utility [checkpoint: 3b8c931]
- [x] Task: Create the `win-notify` script in `modules/common/wsl.nix`. be43af6
    - [x] Implement PowerShell toast logic, including dynamically getting the Windows Terminal installation path. be43af6
    - [x] Ensure script is in path. be43af6
- [x] Task: Conductor - User Manual Verification 'Notification Utility' (Protocol in workflow.md) 3b8c931

## Phase 2: Fish Shell Hooks [checkpoint: 123aad9]
- [x] Task: Implement command completion notification. 5b75812
- [x] Task: Implement 'Action Required' and 'Ready' title monitoring. 5b75812
- [x] Task: Implement Sudo password prompt detection. 5b75812
- [x] Task: Implement 'Long Task' notification (3+ minutes). 5b75812
    - [x] Add a background timer or check in Fish for tasks exceeding 3 minutes. 5b75812
- [x] Task: Implement "High Demand" message detection. 73370dd
    - [x] Use Fish hooks or a background process to detect the specific message. 73370dd
- [x] Task: Conductor - User Manual Verification 'Fish Shell Hooks' (Protocol in workflow.md) 73370dd

## Phase 3: Integration & Cleanup
- [x] Task: Final integration and configuration options. 123aad9
- [x] Task: Conductor - User Manual Verification 'Integration & Cleanup' (Protocol in workflow.md) 123aad9
