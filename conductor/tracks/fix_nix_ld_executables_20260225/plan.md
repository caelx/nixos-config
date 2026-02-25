# Implementation Plan: Fix NixOS Dynamic Executables

## Phase 1: Enable nix-ld
- [~] Task: Enable nix-ld in common configuration
    - [ ] Add `programs.nix-ld.enable = true;` to `modules/common/default.nix`.
- [ ] Task: Rebuild and Verify
    - [ ] Run `sudo nixos-rebuild switch --flake .#launch-octopus` (or relevant host).
    - [ ] Verify `code .` starts.
