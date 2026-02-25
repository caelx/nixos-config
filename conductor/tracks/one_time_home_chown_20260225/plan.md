# Implementation Plan: One-Time Home Directory Ownership Fix

## Phase 1: Implement Home Manager Activation Script

- [ ] Task: Update `home/nixos.nix` with a `home.activation` script.
    - [ ] Add `home.activation.homeChown` entry.
    - [ ] Implement check for `/home/nixos/.local/state/nix/home_chown.done`.
    - [ ] Run `chown -R nixos:nixos /home/nixos`.
    - [ ] Create sentinel file and directory.
- [ ] Task: Verify the changes.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Implement Activation Script' (Protocol in workflow.md)

## Phase 2: Testing and Checkpointing

- [ ] Task: Rebuild on NixOS and verify.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Testing and Checkpointing' (Protocol in workflow.md)
