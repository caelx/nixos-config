# Implementation Plan: WSL-Specific Common Settings

## Phase 1: Shared WSL Logic
- [x] Task: Refactor `modules/common/default.nix` (f776541) to remove global `systemd-networkd`
- [ ] Task: Create `modules/common/wsl.nix` with DNS and networking tweaks
- [ ] Task: Import `modules/common/wsl.nix` in `hosts/launch-octopus/default.nix`
- [ ] Task: Update `conductor/product-guidelines.md` with WSL architecture notes
- [ ] Task: Conductor - User Manual Verification 'Phase 1: WSL Shared Logic' (Protocol in workflow.md)
