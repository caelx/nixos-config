# Implementation Plan: Update NixOS to 25.11

## Phase 1: Flake Update and Dry Run

- [ ] Task: Update `nixpkgs` and `home-manager` URLs in `flake.nix`.
- [ ] Task: Update flake lock file (`nix flake update`).
- [ ] Task: Dry-run rebuild to identify immediate configuration errors (`nixos-rebuild build --dry-run`).
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Flake Update and Dry Run' (Protocol in workflow.md)

## Phase 2: Configuration Adjustment

- [ ] Task: Update `home.stateVersion` in `home/nixos.nix` to `25.11`.
- [ ] Task: Fix any deprecated options found during Phase 1 dry run.
- [ ] Task: Final rebuild and switch (`sudo nixos-rebuild switch`).
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Configuration Adjustment' (Protocol in workflow.md)