# Implementation Plan: Deep System Cleanup and Generation Pruning

## Phase 1: Preparation and Pruning [checkpoint: f638622]

- [x] Task: Record current disk usage (`df -h /nix/store`). (Initial: 26G) 102b1eb
- [x] Task: List current system and Home Manager generations. 102b1eb
- [x] Task: Delete old Home Manager generations. 102b1eb
- [x] Task: Delete all old NixOS system generations (`sudo nix-collect-garbage -d`). 102b1eb
- [x] Task: Conductor - User Manual Verification 'Phase 1: Preparation and Pruning' (Protocol in workflow.md) f638622

## Phase 2: Garbage Collection and Finalization

- [ ] Task: Run aggressive Nix garbage collection (`nix-store --gc`).
- [ ] Task: Optimize the Nix store (`nix-store --optimize`).
- [ ] Task: Verify remaining generations and record new disk usage.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Garbage Collection and Finalization' (Protocol in workflow.md)