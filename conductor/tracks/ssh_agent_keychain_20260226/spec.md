# Specification: SSH Agent with Keychain (Revised)

## Overview
Implement a user-specific SSH agent using the `keychain` utility, managed by a user-level `systemd` service via Home Manager. This provides a seamless, persistent agent experience, independent of the interactive shell, and avoids the complexities of GPG-agent while ensuring that SSH keys are managed efficiently.

## Functional Requirements
- **Package Installation**: Install `keychain` via Home Manager (`home.packages`).
- **User Systemd Service**: Create a user-level `systemd` service (via Home Manager's `systemd.user.services`) to start and manage `keychain` upon user login.
    - The service should start `keychain` to manage `ssh-agent`.
    - It should ensure `keychain` exports the necessary environment variables to a well-known file (e.g., `~/.config/keychain-env`).
- **Shell Environment Sourcing**: Configure the Fish shell (`programs.fish.interactiveShellInit`) to source the environment variables exported by `keychain`.
- **SSH Client Configuration**: Configure `programs.ssh.addKeysToAgent = "yes"` (or the equivalent `extraConfig`). This ensures that keys are added to the running agent as soon as they are used.

## Non-Functional Requirements
- **Persistence**: The SSH agent (managed by `keychain`) must persist across user logouts and reboots, automatically restarting.
- **Shell Agnostic**: The SSH agent should be accessible from any shell session (Fish, Bash, etc.) by sourcing the environment variables.
- **Reliability**: The setup should handle cases where an agent is already running or needs to be restarted gracefully.
- **Simplicity**: Avoid complex GPG-agent configurations.

## Acceptance Criteria
- [ ] `keychain` package is installed and functional.
- [ ] A user-level `systemd` service for `keychain` is active and running.
- [ ] Environment variables (`SSH_AUTH_SOCK`, etc.) are correctly set in new Fish shell sessions.
- [ ] Running `ssh` with a key for the first time automatically adds that key to the agent (verify with `ssh-add -l`).
- [ ] The `ssh-agent` process (managed by `keychain`) remains active after logging out and back in.

## Out of Scope
- GPG-agent or `gpg-connect-agent` configuration.
- System-wide (root) SSH agent configuration (beyond user service).