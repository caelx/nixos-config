# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-03-10

### Added
- **Automated Host Bootstrap**: Implemented an automated bootstrap process in `modules/common/bootstrap.nix` that triggers during the first `nixos-rebuild switch`.
- **SOPS Key Generation**: Automatic generation of SOPS age keys for new hosts during activation.
- **Hardware Config Generation**: Automatic generation of a temporary `hardware-configuration.nix` during initial activation.
- **Bootstrap Utility**: Added `bootstrap-host` CLI tool for manual/interactive host initialization.
- **Documentation**: Added comprehensive "Bootstrap a New Host" section to `README.md`.

### Changed
- **Secrets Module Cleanup**: Refactored `modules/common/secrets.nix` to remove bootstrap-related logic, delegating it to the new `bootstrap.nix` module.

## [0.1.1] - 2026-03-09

### Added
- **System Skill Update**: Added `nh os build` to the Command Reference Matrix for testing NixOS configurations.

## [0.1.0] - 2026-03-09

### Added
- **Automated Maintenance**: Configured automated daily Nix garbage collection and system generation pruning (keeping 7 days) in `modules/common/default.nix`.
- **Maintenance Documentation**: Added a "Maintenance & Cleanup" section to `README.md` with instructions for `nh clean`.
- **System Skill Update**: Reinforced the "Documentation Mandate" and added "Versioning & Conductor" autoincrement logic in `home/config/skills/system.md`.
- **Version Tracking**: Created the `VERSION` file and initialized it at `0.1.0`.
- **Initial Changelog**: Created `CHANGELOG.md` to track project evolution.

### Changed
- **Config Apply Workflow**: Updated documentation to prefer `nh os switch` over `nixos-rebuild`.
- **Memory Policy**: Updated `GEMINI.md` to track the new maintenance automation.
