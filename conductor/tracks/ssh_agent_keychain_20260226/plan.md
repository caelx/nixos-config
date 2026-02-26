# Implementation Plan: SSH Agent with Systemd and Fish Shell Integration

## Phase 1: SSH Agent Systemd Service and Fish Integration

- [x] Task: Remove `keychain` from `home.packages` and `keychain` initialization from `programs.fish.interactiveShellInit`. 6e41f1b
- [x] Task: Ensure `services.ssh-agent.enable = true;` is configured in `home/nixos.nix`. 324aa78
- [x] Task: Create a custom Fish script to detect and configure `ssh-agent` environment variables on shell login. 4cbb9f8
- [ ] Task: Conductor - User Manual Verification 'Phase 1: SSH Agent Systemd Service and Fish Integration' (Protocol in workflow.md)

## Phase 2: SSH Client Configuration

- [ ] Task: Configure `programs.ssh.addKeysToAgent`.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: SSH Client Configuration' (Protocol in workflow.md)