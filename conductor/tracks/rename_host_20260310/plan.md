# Implementation Plan: Rename `boomer-kuwanger` to `boomer-kuwanger`

## Phase 1: Preparatory Search & Registry Update
- [x] Task: Generate a comprehensive list of all affected files and directories containing `boomer-kuwanger`.
- [x] Task: Update `conductor/tracks.md` to reflect the new host name in track titles and links.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Preparatory Search & Registry Update' (Protocol in workflow.md)

## Phase 2: System-Wide Renaming
- [x] Task: Use `git mv` to rename the host directory: `hosts/boomer-kuwanger` -> `hosts/boomer-kuwanger`.
- [x] Task: Rename all active track directories in `conductor/tracks/` that contain the old name.
- [x] Task: Rename all archived track directories in `conductor/archive/` that contain the old name.
- [x] Task: Update `flake.nix` and `hosts/boomer-kuwanger/default.nix` to use the new host configuration name.
- [x] Task: Conductor - User Manual Verification 'Phase 2: System-Wide Renaming' (Protocol in workflow.md)

## Phase 3: Global String Replacement
- [x] Task: Perform a global search and replace of `armored-armadillo` with `boomer-kuwanger` across all text files.
- [x] Task: Specifically update all track `metadata.json`, `plan.md`, `spec.md`, and `index.md` files to ensure internal consistency.
- [x] Task: Conductor - User Manual Verification 'Phase 3: Global String Replacement' (Protocol in workflow.md)

## Phase 4: Validation & Cleanup
- [x] Task: Perform a recursive search for `armored-armadillo` to ensure total removal (excluding `.git` and secrets).
- [x] Task: Verify that `nix flake check` passes with the new hostname.
- [x] Task: Ensure all Conductor track links are functional and pointing to the correct directories.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Validation & Cleanup' (Protocol in workflow.md)
