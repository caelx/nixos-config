# Implementation Plan: Add inshellisense and integrate it into Fish

## Phase 1: Package Installation
- [x] **Task: Write Verification Test for Package Installation** (096c4b6)
    - [ ] Create `tests/verify_inshellisense_install.sh` that checks if `inshellisense` is available in the user path.
    - [ ] Run the script and confirm it fails (Red Phase).
- [ ] **Task: Add inshellisense to Home Manager Configuration**
    - [ ] Update `home/nixos.nix` to include `inshellisense` in `home.packages`.
- [ ] **Task: Verify Package Installation**
    - [ ] Run `home-manager build` (or `nixos-rebuild build`) to ensure the package is pulled into the store.
    - [ ] Run the verification script (Green Phase).
- [ ] **Task: Conductor - User Manual Verification 'Phase 1: Package Installation' (Protocol in workflow.md)**

## Phase 2: Fish Shell Integration
- [ ] **Task: Write Verification Test for Fish Integration**
    - [ ] Create `tests/verify_fish_integration.sh` that checks if `inshellisense --init fish | source` exists in the generated Fish config.
    - [ ] Run the script and confirm it fails (Red Phase).
- [ ] **Task: Configure Fish Initialization**
    - [ ] Update `programs.fish.interactiveShellInit` in `home/nixos.nix` to include the `inshellisense` initialization command.
- [ ] **Task: Verify Fish Integration**
    - [ ] Rebuild the configuration and run the verification script (Green Phase).
- [ ] **Task: Conductor - User Manual Verification 'Phase 2: Fish Shell Integration' (Protocol in workflow.md)**

## Phase 3: System Activation & Final Check
- [ ] **Task: Apply Configuration**
    - [ ] Run `sudo nixos-rebuild switch --flake .#launch-octopus`.
- [ ] **Task: Final Manual Verification**
    - [ ] Open a new Fish shell and verify that `inshellisense` provides autocomplete suggestions.
- [ ] **Task: Conductor - User Manual Verification 'Phase 3: System Activation & Final Check' (Protocol in workflow.md)**
