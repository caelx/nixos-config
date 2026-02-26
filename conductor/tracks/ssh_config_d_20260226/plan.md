# Implementation Plan: SSH Config.d Directory Management

## Phase 1: SSH Config.d Management

- [x] Task: Configure Home Manager `home.file` to create and manage `~/.ssh/conf.d/` with correct permissions. a345e0c
- [x] Task: Configure `programs.ssh` to include `~/.ssh/conf.d/*`. 8eb0a2a
- [ ] Task: Conductor - User Manual Verification 'Phase 1: SSH Config.d Management' (Protocol in workflow.md)

## Phase 2: SSH Configuration Refactor

- [x] Task: Move global options to top-level and consolidate `matchBlocks."*"`. 700eb51
- [ ] Task: Conductor - User Manual Verification 'Phase 2: SSH Configuration Refactor' (Protocol in workflow.md)