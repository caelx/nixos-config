# Implementation Plan: Refactor Primary User to 'nixos'

## Phase 1: User Migration
- [x] Task: Rename `home/cael.nix` (bf58c69) to `home/nixos.nix` and update content
- [x] Task: Update `hosts/launch-octopus/default.nix` (7d036df) with `nixos` user and group IDs
- [ ] Task: Update `flake.nix` to map `home/nixos.nix` to the `nixos` user
- [ ] Task: Update `conductor/product-guidelines.md` to reflect the `nixos` user standard
- [ ] Task: Conductor - User Manual Verification 'Phase 1: User Migration' (Protocol in workflow.md)
