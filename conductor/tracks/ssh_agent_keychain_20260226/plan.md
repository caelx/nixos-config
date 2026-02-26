# Implementation Plan: SSH Agent with Keychain

## Phase 1: Keychain Installation and Systemd Service Setup

- [ ] Task: Install `keychain` package via Home Manager.
- [ ] Task: Define Home Manager `systemd.user.services` for `keychain`.
    - [ ] Configure `keychain` to manage `ssh-agent`.
    - [ ] Configure `keychain` to export environment variables to a well-known file (e.g., `~/.config/keychain-env`).
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Keychain Installation and Systemd Service Setup' (Protocol in workflow.md)

## Phase 2: Shell Integration and SSH Client Configuration

- [ ] Task: Configure Fish shell to source `keychain` environment variables.
- [ ] Task: Configure `programs.ssh.addKeysToAgent`.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Shell Integration and SSH Client Configuration' (Protocol in workflow.md)