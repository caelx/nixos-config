# Specification: Windows Notifications for WSL2

## Overview
Implement a notification bridge between NixOS (WSL2) and the Windows host. This system will alert the user when terminal tasks complete, when "Action Required" states are detected (via title or sudo prompt), and when long-running tasks exceed a specific time threshold.

## Functional Requirements
1. **Windows Notification Utility (`win-notify`):**
   - A shell script that calls `powershell.exe` to display a Windows Toast.
   - Supports custom messages.
   - Dynamically determines the Windows Terminal installation path using `(Get-AppxPackage -Name Microsoft.WindowsTerminal).InstallLocation` for robust notification delivery.
2. **Fish Shell Hooks:**
   - **Command Completion:** Notify whenever any command finishes.
   - **Title Monitoring:** Notify when the terminal title is set to "Action Required" or "Ready".
   - **Sudo Detection:** Notify when `[sudo] password for` appears or is likely prompted.
   - **Long Task Alert:** Notify if a task has been running for more than 3 minutes.
   - **"High Demand" Message:** Notify when the specific phrase "We are currently experiencing high demand" appears in the terminal output.
3. **Declarative NixOS Integration:**
   - Configured via Nix modules for WSL hosts.

## Technical Approach
- **Toast:** `powershell.exe -Command "New-BurntToastNotification ..."` or simpler PS native calls.
- **Monitoring:** Fish `postexec` hooks and wrapping title-setting functions.
- **Sudo:** Possible wrapper for `sudo` to trigger a pre-notification.
- **Timer:** Use Fish shell variables (`$CMD_DURATION`) or background jobs.

## Acceptance Criteria
- `win-notify` works from the CLI.
- Notifications trigger on command finish.
- Notifications trigger on "Action Required" title change.
- Notifications trigger on sudo prompt (best effort).
- Notifications trigger for tasks > 3 mins.
