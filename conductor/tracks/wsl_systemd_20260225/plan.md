# Implementation Plan: Enable WSL2 Systemd Support

## Phase 1: Flake and Host Configuration
- [x] Task: Add `nixos-wsl` (d3330f7) to `flake.nix` inputs and outputs
- [ ] Task: Update `hosts/launch-octopus/default.nix` to use WSL module and remove incompatible boot settings
- [ ] Task: Clean up `hosts/launch-octopus/hardware-configuration.nix`
- [ ] Task: Conductor - User Manual Verification 'Phase 1: WSL Configuration' (Protocol in workflow.md)
