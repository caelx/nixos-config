# Specification: Setup Hyper-V Dev VM (armored-armadillo-dev)

## Overview
Create a new NixOS configuration for a Hyper-V virtual machine named `armored-armadillo-dev`. This VM will serve as a development and testing environment for the `armored-armadillo` host profile, adapted for the Hyper-V hypervisor.

## Functional Requirements
- **Host Configuration**: Define a new NixOS host `armored-armadillo-dev` in `flake.nix`.
- **Hardware Configuration**: Create a `hardware-configuration.nix` optimized for Hyper-V (Generation 2 VM).
- **Resource Allocation**:
  - RAM: 8GB (Standard).
  - CPU Cores: 4.
  - Disk: 64GB VHDX.
- **Networking**: Use the Hyper-V "Default Switch".
- **OS Installation**:
  - Use the specified ISO: `/home/nixos/win-home/Downloads/nixos-minimal-25.11.7198.71caefce12ba-x86_64-linux.iso`.
  - Perform an initial bootstrap of the VM using the new configuration.
- **Profile Adaptation**: Clone the core settings of `armored-armadillo` but replace hardware-specific AMD GPU/CPU optimizations with Hyper-V guest services.

## Non-Functional Requirements
- **Reproducibility**: The VM configuration must be fully declarative within the existing flake.
- **Consistency**: Use the same user (`nixos`) and shared modules as other hosts.

## Acceptance Criteria
- [ ] `armored-armadillo-dev` host is defined in `flake.nix`.
- [ ] VM is successfully created in Hyper-V with 8GB RAM, 4 vCPUs, and 64GB disk.
- [ ] VM boots from the provided NixOS ISO.
- [ ] VM can be provisioned with the new configuration.
- [ ] Hyper-V guest services (integration features) are enabled and functional.

## Out of Scope
- Physical hardware optimizations for AMD GPUs (since this is a VM).
- Migration of existing data from a physical `armored-armadillo` host.
