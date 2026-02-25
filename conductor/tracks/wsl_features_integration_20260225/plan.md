# Implementation Plan: WSL2 Features Integration

## Phase 1: WSLENV & Path Integration
- [x] Task: Configure `WSLENV` for `USERPROFILE/p` sharing (38bb7f2)
    - [ ] Add `wsl.wslConf.interop.enabled = true` to common WSL config
    - [ ] Use `wsl.wslConf.automount.enabled = true` (if not already enabled)
    - [ ] Update `modules/common/wsl.nix` with the `WSLENV` setting
- [x] Task: Implement `~/win-home` Symlink Creation (1ab0880)
    - [ ] Create a NixOS activation script to dynamically link `~/win-home` based on the `$USERPROFILE` environment variable.
- [ ] Task: Conductor - User Manual Verification 'WSLENV & Path Integration' (Protocol in workflow.md)

## Phase 2: Explorer & Navigation
- [x] Task: Install and Configure `wsl-open` (568dc0a)
    - [x] Add `wsl-open` to `environment.systemPackages` in `modules/common/wsl.nix` (568dc0a)
- [ ] Task: Create `open` Alias (Deferred: To be configured with shell setup)
    - [ ] Update shell configuration (common home-manager or bash/fish) to add `alias open="wsl-open"`
- [~] Task: Conductor - User Manual Verification 'Explorer & Navigation' (Protocol in workflow.md)

## Phase 3: Multimedia & Services
- [ ] Task: Enable Clipboard Sharing
    - [ ] Research and enable `nixos-wsl.wslConf.interop.includePath` or similar if needed for clipboard tools (e.g., `clip.exe`).
- [ ] Task: Configure PulseAudio for Windows Sound
    - [ ] Add PulseAudio configuration to `modules/common/wsl.nix` to allow sound to flow to the Windows host.
- [ ] Task: Docker Desktop Compatibility Check
    - [ ] Verify if the current user is added to the `docker` group and ensure the host config allows Docker socket access.
- [ ] Task: Conductor - User Manual Verification 'Multimedia & Services' (Protocol in workflow.md)
