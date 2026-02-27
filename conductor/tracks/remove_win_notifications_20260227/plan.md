# Implementation Plan: Remove Legacy Windows Notification Bridge

## Phase 1: Code Cleanup [checkpoint: ]

- [ ] Task: Remove `win-notify` integrations from `home/wsl.nix`.
- [ ] Task: Remove `win-notify` usage in `modules/common/gemini.nix`.
- [ ] Task: Conductor - User Manual Verification 'Code Cleanup' (Protocol in workflow.md)

## Phase 2: Tool and Script Removal [checkpoint: ]

- [ ] Task: Delete the `win-notify` script definition from `modules/common/wsl.nix`.
- [ ] Task: Verify the system builds without the notification bridge: `sudo nixos-rebuild build --flake .#launch-octopus`.
- [ ] Task: Conductor - User Manual Verification 'Tool and Script Removal' (Protocol in workflow.md)

## Phase 3: Track and Documentation Removal [checkpoint: ]

- [ ] Task: Remove `win-notify` entry from `conductor/tech-stack.md`.
- [ ] Task: Remove "Windows Notifications for WSL2" from `conductor/tracks.md`.
- [ ] Task: Delete the track directory `conductor/tracks/win_notifications_20260227/`.
- [ ] Task: Conductor - User Manual Verification 'Track and Documentation Removal' (Protocol in workflow.md)
