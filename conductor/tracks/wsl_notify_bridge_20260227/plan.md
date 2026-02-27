# Implementation Plan: WSL notify-send Bridge

## Phase 1: Research and Prototyping [checkpoint: 9abd5c3]
- [x] Task: Research PowerShell command for modern Windows toast notifications without external dependencies. [fb18438]
- [x] Task: Prototype a direct `powershell.exe` call from WSL to trigger a notification with title and body. [7812957]
- [x] Task: Conductor - User Manual Verification 'Phase 1' (Protocol in workflow.md) [9abd5c3]

## Phase 2: Bridge Script Implementation
- [x] Task: Develop the `notify-send` Bash wrapper that parses standard flags (`-a`, `-i`, `-u`, `-t`). [70c8e29]
- [x] Task: Implement path translation for icons (Linux path to `/mnt/c/...` or Windows path). [b25bd7a]
- [x] Task: Finalize the inline PowerShell snippet within the Bash script. [4cb4000]
- [ ] Task: Conductor - User Manual Verification 'Phase 2' (Protocol in workflow.md)

## Phase 3: NixOS Integration
- [ ] Task: Create a new module or package definition in `modules/common/wsl.nix` for the `notify-send` bridge.
- [ ] Task: Add the package to `environment.systemPackages` for the WSL host.
- [ ] Task: Perform a `nixos-rebuild switch --flake .#launch-octopus` to deploy the new tool.
- [ ] Task: Conductor - User Manual Verification 'Phase 3' (Protocol in workflow.md)

## Phase 4: Final Verification and Documentation
- [ ] Task: Verify the bridge with various flags (app-name, urgency, icon).
- [ ] Task: Update `README.md` to document the availability of `notify-send` in WSL.
- [ ] Task: Conductor - User Manual Verification 'Phase 4' (Protocol in workflow.md)
