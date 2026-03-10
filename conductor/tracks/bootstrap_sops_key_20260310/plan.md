# Implementation Plan: Bootstrap SOPS Key Generation

## Phase 1: Implementation
- [ ] Task: Define the high-priority activation script in `modules/common/secrets.nix`.
- [ ] Task: Implement the check for the age key and the generation logic.
- [ ] Task: Implement the terminal output with the public key and instructional guidance.
- [ ] Task: Implement the non-zero exit to halt the activation process.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Implementation' (Protocol in workflow.md)

## Phase 2: Verification
- [ ] Task: Test the bootstrap process by temporarily moving the existing age key on the current host.
- [ ] Task: Verify that the public key is correctly displayed and the build halts as expected.
- [ ] Task: Verify that after restoring the key (or adding the new one) and re-applying, the build completes successfully.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Verification' (Protocol in workflow.md)
