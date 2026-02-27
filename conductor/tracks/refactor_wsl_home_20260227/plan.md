# Implementation Plan: Refactor WSL-specific Home Manager Configuration

## Phase 1: Configuration Refactoring

- [ ] Task: Create `home/wsl.nix` with extracted WSL-specific Home Manager logic (ssh-agent, wsl-open, fish init).
- [ ] Task: Remove WSL-specific logic from `home/nixos.nix` and add a conditional import checking `osConfig.wsl.enable`.
- [ ] Task: Conductor - User Manual Verification 'Configuration Refactoring' (Protocol in workflow.md)

## Phase 2: Verification and System Switch

- [ ] Task: Build the configuration to ensure no syntax or logical errors: `sudo nixos-rebuild build --flake .#launch-octopus`.
- [ ] Task: Switch to the new configuration on the `launch-octopus` host: `sudo nixos-rebuild switch --flake .#launch-octopus`.
- [ ] Task: Verify that `open` still works as `wsl-open` in a new Fish session.
- [ ] Task: Verify that `systemctl --user status ssh-agent` is active and `~/.config/ssh-agent.env` is correctly generated.
- [ ] Task: Conductor - User Manual Verification 'Verification and System Switch' (Protocol in workflow.md)
