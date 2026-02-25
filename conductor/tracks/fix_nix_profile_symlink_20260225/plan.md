# Implementation Plan: Fix Nix Profile Symlink

## Phase 1: Explicitly Manage Symlink in Home Manager

- [ ] Task: Add `.nix-profile` to `home.file` in `home/nixos.nix`.
    - [ ] Create a Home Manager file entry for `~/.nix-profile`.
    - [ ] Point it to `config.home.homeDirectory + "/.local/state/nix/profiles/home-manager"`.
    - [ ] Use `force = true;` to ensure it overwrites the existing (broken) symlink.
- [ ] Task: Verify the changes.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Explicitly Manage Symlink' (Protocol in workflow.md)

## Phase 2: Testing and Checkpointing

- [ ] Task: Rebuild on NixOS and verify the symlink's target.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Testing and Checkpointing' (Protocol in workflow.md)
