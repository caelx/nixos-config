# Implementation Plan: Rename `armored-armadillo` to `boomer-kuwanger`

## Phase 1: Preparatory Search & Registry Update
- [ ] Task: Generate a comprehensive list of all affected files and directories containing `armored-armadillo`.
- [ ] Task: Update `conductor/tracks.md` to reflect the new host name in track titles and links.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Preparatory Search & Registry Update' (Protocol in workflow.md)

## Phase 2: System-Wide Renaming
- [ ] Task: Use `git mv` to rename the host directory: `hosts/armored-armadillo` -> `hosts/boomer-kuwanger`.
- [ ] Task: Rename all active track directories in `conductor/tracks/` that contain the old name.
- [ ] Task: Rename all archived track directories in `conductor/archive/` that contain the old name.
- [ ] Task: Update `flake.nix` and `hosts/boomer-kuwanger/default.nix` to use the new host configuration name.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: System-Wide Renaming' (Protocol in workflow.md)

## Phase 3: Global String Replacement
- [ ] Task: Perform a global search and replace of `armored-armadillo` with `boomer-kuwanger` across all text files.
- [ ] Task: Specifically update all track `metadata.json`, `plan.md`, `spec.md`, and `index.md` files to ensure internal consistency.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Global String Replacement' (Protocol in workflow.md)

## Phase 4: Validation & Cleanup
- [ ] Task: Perform a recursive search for `armored-armadillo` to ensure total removal (excluding `.git` and secrets).
- [ ] Task: Verify that `nix flake check` passes with the new hostname.
- [ ] Task: Ensure all Conductor track links are functional and pointing to the correct directories.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Validation & Cleanup' (Protocol in workflow.md)
