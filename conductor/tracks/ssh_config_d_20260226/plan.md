# Implementation Plan: SSH Config.d Directory Management

## Phase 1: SSH Config.d Management

- [x] Task: Configure Home Manager `home.file` to create and manage `~/.ssh/conf.d/` with correct permissions. a345e0c
- [x] Task: Configure `programs.ssh` to include `~/.ssh/conf.d/*`. 8eb0a2a
- [ ] Task: Conductor - User Manual Verification 'Phase 1: SSH Config.d Management' (Protocol in workflow.md)

## Phase 2: SSH Configuration Refactor and Agent Timeout

- [x] Task: Consolidate all SSH options into a single `matchBlocks."*"` block. 7eb37ae
- [x] Task: Configure `services.ssh-agent` with a 15-minute key timeout (`-t 15m`). 056d283
- [ ] Task: Conductor - User Manual Verification 'Phase 2: SSH Configuration Refactor and Agent Timeout' (Protocol in workflow.md)