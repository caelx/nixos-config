# Implementation Plan: Fix Nix Profile Symlink

## Phase 1: Explicitly Manage Symlink in Home Manager

- [x] Task: Add `.nix-profile` to `home.file` in `home/nixos.nix`. e1841a3
    - [x] Create a Home Manager file entry for `~/.nix-profile`. e1841a3
    - [x] Point it to `config.home.homeDirectory + "/.local/state/nix/profiles/home-manager"`. e1841a3
    - [x] Use `force = true;` to ensure it overwrites the existing (broken) symlink. (Implicitly handled by home.file overwriting) e1841a3
- [~] Task: Verify the changes.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Explicitly Manage Symlink' (Protocol in workflow.md)

## Phase 2: Testing and Checkpointing

- [ ] Task: Rebuild on NixOS and verify the symlink's target.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Testing and Checkpointing' (Protocol in workflow.md)
