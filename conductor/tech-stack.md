# Tech Stack: Unified NixOS Configuration Repository

## Core Nix Ecosystem
- **Nix & Nix Flakes**: The foundation for dependency management, reproducible builds, and standardized outputs.
- **NixOS**: The primary operating system for all managed hosts.
- **Home Manager**: For managing user-level configurations and dotfiles across all systems.
- **nixos-hardware**: Community-maintained repository of optimized hardware configurations.

## Deployment & Automation
- **Git-Based Auto-Upgrades**: Use `system.autoUpgrade` to automatically pull, build, and switch to new configurations from the `main` branch.
- **nixos-rebuild**: The primary tool for local system management and initial bootstrapping.

## Security & Secrets
- **sops-nix**: Integration of Mozilla SOPS with NixOS for secure, encrypted secret management (using `age` or `gpg`).

## Development & Utility Tools
- **nh (Nix Helper)**: A modern, user-friendly wrapper for common Nix CLI operations.
- **direnv & nix-direnv**: For automatic, fast, and persistent development environment loading.
- **nvd (Nix Visual Diff)**: For analyzing differences between Nix package generations.
- **comma (, )**: To run any binary from nixpkgs without permanent installation.
- **nix-ld**: For running dynamically linked executables intended for generic Linux environments (e.g., VS Code Remote Server).
- **pre-commit-hooks.nix**: To enforce code quality and formatting before commits.
- **Modern CLI Tools**: eza (replacement for ls), bat, fd, zoxide, and starship for a feature-rich shell experience.
- **Fish Shell**: The primary interactive shell, pre-configured with aliases and plugins.
