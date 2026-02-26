# Implementation Plan: Deep System Cleanup and Generation Pruning

## Phase 1: Preparation and Pruning

- [ ] Task: Record current disk usage (`df -h /nix/store`).
- [ ] Task: List current system and Home Manager generations.
- [ ] Task: Delete old Home Manager generations.
- [ ] Task: Delete all old NixOS system generations (`sudo nix-collect-garbage -d`).
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Preparation and Pruning' (Protocol in workflow.md)

## Phase 2: Garbage Collection and Finalization

- [ ] Task: Run aggressive Nix garbage collection (`nix-store --gc`).
- [ ] Task: Optimize the Nix store (`nix-store --optimize`).
- [ ] Task: Verify remaining generations and record new disk usage.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Garbage Collection and Finalization' (Protocol in workflow.md)