# Specification: SSH Agent with Keychain (Shell Login)

## Overview
Implement a user-specific SSH agent using the `keychain` utility, initialized within the Fish shell on login. This approach ensures the agent starts with the user's shell session, avoids `systemd` complexities for `keychain`, and prevents multiple `ssh-agent` instances while providing a seamless experience.

## Functional Requirements
- **Package Installation**: Install `keychain` via Home Manager (`home.packages`).
- **Home Manager `services.ssh-agent`**: Ensure `services.ssh-agent.enable = true;` is configured in `home/nixos.nix` to allow `keychain` to manage `ssh-agent`.
- **Fish Shell Integration**: Configure `programs.fish.interactiveShellInit` in `home/nixos.nix` to initialize `keychain` on login.
    - The initialization script should ensure `keychain` starts `ssh-agent` only if one is not already running.
    - It should export the necessary environment variables (`SSH_AUTH_SOCK`, `SSH_AGENT_PID`) to the current shell.
- **SSH Client Configuration**: Configure `programs.ssh.addKeysToAgent = "yes"` (or the equivalent `extraConfig`). This ensures that keys are added to the running agent as soon as they are used.

## Non-Functional Requirements
- **No Duplicate Agents**: `keychain` must prevent the launch of multiple `ssh-agent` instances.
- **Seamless Login**: The agent should start or connect to an existing instance on shell login without user intervention or noticeable delay.
- **Persistence**: `keychain` should manage agent persistence across shell sessions.
- **Simplicity**: Avoid complex GPG-agent configurations and `systemd` user service definitions for `keychain` itself.

## Acceptance Criteria
- [ ] `keychain` package is installed and functional.
- [ ] `services.ssh-agent.enable = true;` is configured.
- [ ] Opening a new Fish shell initializes `keychain`, which then connects to or starts an `ssh-agent`.
- [ ] Only one `ssh-agent` process is running after opening multiple Fish shells.
- [ ] `SSH_AUTH_SOCK` and `SSH_AGENT_PID` environment variables are correctly set in the Fish shell.
- [ ] Running `ssh` with a key for the first time automatically adds that key to the agent (verify with `ssh-add -l`).

## Out of Scope
- Direct `systemd` user service configuration for `keychain`.
- GPG-agent or `gpg-connect-agent` configuration.
- System-wide (root) SSH agent configuration.