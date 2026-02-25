# Implementation Plan: One-Time Home Directory Ownership Fix

## Phase 1: Implement Home Manager Activation Script

- [x] Task: Update `home/nixos.nix` with a `home.activation` script. ca0df5c
    - [x] Add `home.activation.homeChown` entry. ca0df5c
    - [x] Implement check for `/home/nixos/.local/state/nix/home_chown.done`. ca0df5c
    - [x] Run `chown -R nixos:nixos /home/nixos`. ca0df5c
    - [x] Create sentinel file and directory. ca0df5c
- [~] Task: Verify the changes.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Implement Activation Script' (Protocol in workflow.md)

## Phase 2: Testing and Checkpointing

- [ ] Task: Rebuild on NixOS and verify.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Testing and Checkpointing' (Protocol in workflow.md)
