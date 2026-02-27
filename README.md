# NixOS Configuration Fleet

This repository contains the NixOS and Home Manager configurations for my fleet of systems.

## Systems
- **launch-octopus**: Primary WSL2 development environment on Windows 11.

## Features
- **Flake-based**: Reproducible system configuration using Nix Flakes.
- **SOPS-Nix**: Secure secrets management.
- **Home Manager**: Declarative user environment management.
- **WSL Integration**:
    - **wsl-open**: Open files/folders in Windows applications from Linux.
    - **notify-send Bridge**: Native Windows toast notifications for Linux applications.
    - **win-home Symlink**: Easy access to Windows user profile at `~/win-home`.

## Usage

### Rebuild System
```bash
sudo nixos-rebuild switch --flake .#launch-octopus
```

### Notifications (WSL)
The standard `notify-send` command is available and forwards to the Windows Action Center:
```bash
notify-send "Hello from WSL" "This notification is shown on Windows."
```
