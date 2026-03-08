# Implementation Plan: Add armored-armadillo Host

## Phase 1: Foundation and Flake Registration
- [x] Task: Create directory structure for `hosts/armored-armadillo/` 73c7157
- [x] Task: Register `armored-armadillo` in `flake.nix` with initial `default.nix` and `hardware-configuration.nix` 888e37f
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Foundation' (Protocol in workflow.md)

## Phase 2: Common Module Integration
- [ ] Task: Import `modules/common/default.nix`, `modules/common/users.nix`, and `modules/common/secrets.nix`
- [ ] Task: Import `modules/common/gemini.nix` and `modules/common/automation.nix`
- [ ] Task: Verify non-WSL modules are correctly imported and evaluated
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Common Module Integration' (Protocol in workflow.md)

## Phase 3: Desktop Environment and Graphics
- [ ] Task: Enable Wayland and Hyprland in `hosts/armored-armadillo/default.nix`
- [ ] Task: Enable XWayland support and Mesa graphics drivers
- [ ] Task: Configure basic display options (non-WSL specific)
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Desktop Environment and Graphics' (Protocol in workflow.md)

## Phase 4: Conditional Hardware Configuration
- [ ] Task: Implement conditional logic in `hosts/armored-armadillo/hardware-configuration.nix` for AMD vs. Gallium
- [ ] Task: Define a configuration option (e.g., `specialisation`) or a module toggle to switch between AMD and Gallium
- [ ] Task: Verify that the configuration builds for both targets
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Conditional Hardware Configuration' (Protocol in workflow.md)
