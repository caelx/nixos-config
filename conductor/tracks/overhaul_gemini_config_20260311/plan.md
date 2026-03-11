# Implementation Plan: Overhaul Gemini CLI & Module Refactor

## Phase 1: Module Refactoring [checkpoint: 54fd4bd]
- [x] Task: Rename `modules/wsl/` to `modules/develop/` [1a203fb]
- [x] Task: Move `modules/common/gemini.nix` to `modules/develop/gemini.nix` [9a98383]
- [x] Task: Update `flake.nix` and host imports to reflect the new `develop` path [f6d1e44]
- [x] Task: Conductor - User Manual Verification 'Module Refactoring' (Protocol in workflow.md) [54fd4bd]

## Phase 2: Gemini Instruction Overhaul
- [~] Task: Distill instructions from `home/config/skills/system.md` into a new global `gemini.md`
- [ ] Task: Integrate `gemini.md` into Home Manager (`home.file` in `home/nixos.nix`)
- [ ] Task: Remove `system` skill from `modules/develop/gemini.nix` (`settings.json`)
- [ ] Task: Delete the `home/config/skills/system.md`, `python.md`, and `hyper-v.md` files
- [ ] Task: Conductor - User Manual Verification 'Gemini Instruction Overhaul' (Protocol in workflow.md)

## Phase 3: Final Verification and Cleanup
- [ ] Task: Run `nh os build` and `nh os switch` to verify the new configuration
- [ ] Task: Verify that Gemini CLI correctly loads the global user `gemini.md`
- [ ] Task: Perform a final cleanup of any unused configuration fragments
- [ ] Task: Conductor - User Manual Verification 'Final Verification and Cleanup' (Protocol in workflow.md)
