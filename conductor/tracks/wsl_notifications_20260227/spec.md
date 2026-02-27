# Specification: WslNotifyd Integration

## Overview
Deploy the [WslNotifyd](https://github.com/ultrabig/WslNotifyd) background service to bridge native Linux D-Bus notifications from the WSL container to Windows 11 Toast notifications.

## Functional Requirements
- **Nix Derivation (.NET 8)**: Create a custom Nix derivation to build `WslNotifyd` from its GitHub source using the **.NET 8 SDK**.
- **Module Directory**: The Nix files and configuration will be housed in a logical directory (e.g., `modules/common/wsl-notifyd/`).
- **Systemd User Service**: Configure a systemd user service that starts automatically upon user login.
- **Global Integration**: Integrate this feature into `modules/common/wsl.nix` or a similar common WSL module.
- **D-Bus Interception**: The daemon must intercept D-Bus notifications and relay them to the Windows-side executable via the interop socket.

## Non-Functional Requirements
- **Modularity**: The implementation should be clean and integrated into existing Nix modules.
- **Reliability**: The service should automatically restart on failure.

## Acceptance Criteria
- `WslNotifyd` binary is successfully built using .NET 8.
- The `wsl-notifyd` systemd user service is enabled and running.
- Executing `notify-send` within WSL results in a native Windows 11 toast notification.

## Out of Scope
- Installation or management of the Windows-side `WslNotifydWin.exe` executable.
