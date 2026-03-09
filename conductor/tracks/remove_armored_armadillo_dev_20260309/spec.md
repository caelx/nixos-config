# Specification: Remove armored-armadillo Dev Configuration

## Overview
This track focuses on the removal of all development-specific configurations for the `armored-armadillo` host. This includes deleting the dedicated development host directory and cleaning up any conditional logic or references within the main host configuration and the root `flake.nix`.

## Functional Requirements
- **Delete Development Host Directory**: Completely remove the `hosts/armored-armadillo-dev/` directory.
- **Cleanup Main Host Config**: Remove any conditional development-specific logic (e.g., Hyper-V or Gallium support) from `hosts/armored-armadillo/default.nix`.
- **Update Root Flake**: Remove the `armored-armadillo-dev` output from `flake.nix`.
- **Reference Integrity**: Ensure no other modules or files imports the deleted development configurations.

## Non-Functional Requirements
- **Maintainability**: Streamline the codebase by removing unused or redundant configurations.
- **Reproducibility**: Ensure that the remaining configurations still build reliably from scratch.

## Acceptance Criteria
- [ ] The `hosts/armored-armadillo-dev/` directory is deleted.
- [ ] `flake.nix` no longer contains a configuration for `armored-armadillo-dev`.
- [ ] `hosts/armored-armadillo/default.nix` is cleaned of dev-specific conditional logic.
- [ ] `nix flake check` (or equivalent build command) succeeds for all remaining hosts.

## Out of Scope
- Removal of any non-dev related configurations for `armored-armadillo`.
- Changes to the `launch-octopus` host.
