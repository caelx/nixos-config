# Implementation Plan: Remove Legacy Windows Notification Bridge

## Phase 1: Code Cleanup [checkpoint: 32469d5]

- [x] Task: Remove `win-notify` integrations from `home/wsl.nix`. 8edc59f
- [x] Task: Remove `win-notify` usage in `modules/common/gemini.nix`. b6a535e
- [ ] Task: Conductor - User Manual Verification 'Code Cleanup' (Protocol in workflow.md)

## Phase 2: Tool and Script Removal [checkpoint: d75c8a0]

- [x] Task: Delete the `win-notify` script definition from `modules/common/wsl.nix`. 2c3efec
- [x] Task: Verify the system builds without the notification bridge: `sudo nixos-rebuild build --flake .#launch-octopus`. 562e759
- [ ] Task: Conductor - User Manual Verification 'Tool and Script Removal' (Protocol in workflow.md)

## Phase 3: Track and Documentation Removal [checkpoint: ]

- [x] Task: Remove `win-notify` entry from `conductor/tech-stack.md`. b643ad2
- [ ] Task: Remove "Windows Notifications for WSL2" from `conductor/tracks.md`.
- [ ] Task: Delete the track directory `conductor/tracks/win_notifications_20260227/`.
- [ ] Task: Conductor - User Manual Verification 'Track and Documentation Removal' (Protocol in workflow.md)
