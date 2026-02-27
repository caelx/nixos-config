# Implementation Plan: Refactor Gemini CLI Wrapper

## Phase 1: Package Refactoring [checkpoint: ]

- [x] Task: Update `modules/common/gemini.nix` to use `makeWrapper`. 6e35081
    - [x] Change the `gemini-cli` definition to use `stdenv.mkDerivation` or `symlinkJoin` with `makeWrapper`.
    - [x] Ensure `${pkgs.nodejs}/bin` is prefixed to the script's `PATH`.
    - [x] Ensure `NODE_NO_WARNINGS=1` is exported in the wrapper.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Package Refactoring' (Protocol in workflow.md)

## Phase 2: Deployment and Verification [checkpoint: ]

- [ ] Task: Apply configuration.
    - [ ] Run `sudo nixos-rebuild switch --flake .#launch-octopus`.
- [ ] Task: Verify functionality.
    - [ ] Run `gemini -y` and verify it works without errors.
    - [ ] Verify that `node` is still NOT available in the global shell.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Deployment and Verification' (Protocol in workflow.md)
