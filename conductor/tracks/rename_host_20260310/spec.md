# Specification: Rename `boomer-kuwanger` to `boomer-kuwanger`

## Overview
This track involves a project-wide rename of the `boomer-kuwanger` host and all its associated references to `boomer-kuwanger`. This includes updating directory names, file contents, and hostnames in the NixOS configuration and Conductor track history.

## Functional Requirements
- **Directory Renaming**: Rename `hosts/boomer-kuwanger` to `hosts/boomer-kuwanger`.
- **String Replacement**: Perform a global search and replace of `boomer-kuwanger` with `boomer-kuwanger` in all text files (`.nix`, `.md`, `.json`, `.toml`, etc.).
- **Conductor Updates**:
    - Update the `conductor/tracks.md` registry.
    - Rename active track directories in `conductor/tracks/` if they contain the old name.
    - Rename archived track directories in `conductor/archive/` if they contain the old name.
    - Update internal references in all track files (`spec.md`, `plan.md`, `metadata.json`, `index.md`).
- **Hostname Update**: Ensure the `networking.hostName` in the new `hosts/boomer-kuwanger/default.nix` is updated.

## Non-Functional Requirements
- **Consistency**: The rename must be thorough to avoid "broken links" in the documentation or configuration.
- **Git Integrity**: Use `git mv` where possible to preserve file history.

## Acceptance Criteria
- [ ] No occurrences of the string `boomer-kuwanger` remain in the repository (excluding `.git`, binary files, and secrets).
- [ ] No directories named `boomer-kuwanger` or containing that string exist.
- [ ] `nix flake check` passes with the new host name.
- [ ] The Conductor registry (`conductor/tracks.md`) links correctly to the renamed tracks.

## Out of Scope
- Re-encrypting `secrets.yaml` or updating `.sops.yaml` with new host-specific age keys (this will be handled manually later).
- Updating actual hardware/BIOS settings (purely a software/configuration rename).
