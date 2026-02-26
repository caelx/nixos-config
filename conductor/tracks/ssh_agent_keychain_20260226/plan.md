# Implementation Plan: SSH Agent with Keychain (Shell Login)

## Phase 1: Keychain Installation and Fish Shell Integration

- [ ] Task: Revert `systemd.user.services.keychain` configuration and ensure `services.ssh-agent.enable = true;`.
- [ ] Task: Configure Fish shell to initialize `keychain` on login, preventing multiple agents and exporting environment variables.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Keychain Installation and Fish Shell Integration' (Protocol in workflow.md)

## Phase 2: SSH Client Configuration

- [ ] Task: Configure `programs.ssh.addKeysToAgent`.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: SSH Client Configuration' (Protocol in workflow.md)