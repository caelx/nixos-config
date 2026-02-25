# Implementation Plan: WSL Username Discovery Fix

## Phase 1: Update Discovery Logic

- [x] Task: Update PowerShell command in `modules/common/wsl.nix` to use `$env:UserName`. b9ba383
    - [x] Modify the `system.activationScripts.wslHomeSymlink` block. b9ba383
    - [ ] Update variable assignment to use `tr -d ''` as specified.
- [~] Task: Update the path construction for Windows user profile.
    - [ ] Use `/mnt/c/Users/<WIN_USER>` as the primary path for discovery.
- [ ] Task: Verify the changes.
    - [ ] Ensure `tr -d ''` is used for cleaning PowerShell output.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Update Discovery Logic' (Protocol in workflow.md)

## Phase 2: Testing and Checkpointing

- [ ] Task: Test the activation script (if possible to run it manually or verify via system rebuild).
- [ ] Task: Verify the symlink `~/win-home` exists and points to the correct Windows user directory.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Testing and Checkpointing' (Protocol in workflow.md)
