# Implementation Plan: WslNotifyd Integration

## Phase 1: Foundation & Derivation
- [ ] Task: Create module directory structure
    - [ ] Create `modules/common/wsl-notifyd/`
- [ ] Task: Create Nix derivation for WslNotifyd
    - [ ] Create `modules/common/wsl-notifyd/derivation.nix` using .NET 8 SDK
    - [ ] Use `fetchFromGitHub` to pull the source from `ultrabig/WslNotifyd`
- [ ] Task: Verify derivation build
    - [ ] Run a test build of the derivation to ensure it compiles correctly with .NET 8
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Foundation & Derivation' (Protocol in workflow.md)

## Phase 2: Configuration & Integration
- [ ] Task: Create NixOS module for WslNotifyd
    - [ ] Create `modules/common/wsl-notifyd/default.nix`
    - [ ] Define the systemd user service to run the daemon
- [ ] Task: Integrate into common WSL configuration
    - [ ] Import and enable the new module in `modules/common/wsl.nix`
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Configuration & Integration' (Protocol in workflow.md)

## Phase 3: Deployment & Final Verification
- [ ] Task: Apply configuration
    - [ ] Run `sudo nixos-rebuild switch --flake .#launch-octopus` (or current host)
- [ ] Task: Verify service operation
    - [ ] Check `systemctl --user status wsl-notifyd`
    - [ ] Test end-to-end with `notify-send "Hello from WSL"`
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Deployment & Final Verification' (Protocol in workflow.md)
