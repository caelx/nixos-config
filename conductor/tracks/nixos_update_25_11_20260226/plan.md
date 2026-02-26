# Implementation Plan: Update NixOS to 25.11

## Phase 1: Flake Update and Dry Run [checkpoint: 16b4685]

- [x] Task: Update `nixpkgs` and `home-manager` URLs in `flake.nix`. 4c8f775
- [x] Task: Update flake lock file (`nix flake update`). 9b3e094
- [x] Task: Dry-run rebuild to identify immediate configuration errors (`nixos-rebuild build --dry-run`). 9b3e094
- [x] Task: Conductor - User Manual Verification 'Phase 1: Flake Update and Dry Run' (Protocol in workflow.md) 16b4685

## Phase 2: Configuration Adjustment

- [ ] Task: Update `home.stateVersion` in `home/nixos.nix` to `25.11`.
- [ ] Task: Fix any deprecated options found during Phase 1 dry run.
- [ ] Task: Final rebuild and switch (`sudo nixos-rebuild switch`).
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Configuration Adjustment' (Protocol in workflow.md)