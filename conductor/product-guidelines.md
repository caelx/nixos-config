# Product Guidelines: Unified NixOS Configuration Repository

## Documentation Standards
- **Inline Rationale**: All non-trivial Nix expressions MUST include detailed inline comments explaining the *intent* and any "gotchas" discovered during implementation.
- **Literate Exploration**: For complex subsystems (e.g., custom secrets logic or complex desktop environments), consider using literate programming techniques or dedicated Markdown overviews to bridge the gap between code and documentation.

## Repository Organization
- **Standard Modular Structure**: The repository will follow a clear, top-level directory structure to separate concerns:
    - `hosts/`: Host-specific configurations and hardware definitions.
    - `modules/`: Shared system-level NixOS modules (nixosModules).
    - `home/`: User-level configurations (home-manager modules).
    - `lib/`: Helper functions and Nix utility logic.
    - `pkgs/`: Custom packages or overlays.
- **Mixed-Platform Fleet Architecture**:
    - The repository is designed to support a heterogeneous fleet (e.g., WSL2 instances and Bare Metal installs like Mac Studio).
    - **Common Logic**: Shared settings (locale, core packages, automation) MUST reside in `modules/common/` and be platform-agnostic.
    - **Platform Integration**: Environmental integrations (e.g., `nixos-wsl`, hardware-specific bootloaders) MUST be handled at the host level or via specialized platform modules, never in the common core.
- **Flake Integration**: The root `flake.nix` will serve as the primary entry point, cleanly exposing `nixosConfigurations`, `homeConfigurations`, and `devShells`.

## User Experience (UX) & Environment
- **Feature-Rich CLI**: The default user environment should be optimized for productivity, featuring a robust shell (e.g., Zsh or Fish), modern CLI replacements (e.g., `bat`, `eza`, `fd`), and pre-configured development tools.
- **Developer-Centric Focus**: Prioritize tools and aliases that streamline Nix-related tasks (e.g., `nh`, `nix-tree`, `nix-output-monitor`).

## Consistency & Upstream Alignment
- **Identity Management**: 
    - All users MUST have their `uid` and `gid` statically set to ensure consistency across different hardware and installations.
    - Usernames MUST be consistently lowercase (e.g., `nixos`).
- **Networking Standard**: 
    - Use `systemd-networkd` as the default networking manager ONLY for hardware hosts (e.g., Mac Studio).
    - WSL2 instances MUST use the shared `modules/common/wsl.nix` module which disables `systemd-resolved` and `networkd` to ensure compatibility with WSL's own networking stack.
- **Git Identity Policy**: Do not set global `user.name` or `user.email` in Home Manager configurations; identity should be managed on a per-project basis using local Git configs.
- **Community Standards**: Follow established Nix community patterns and best practices. Prioritize "the Nix way" over custom abstractions unless necessary.
- **Upstream Alignment**: Where possible, contribute improvements back to upstream projects (e.g., nixpkgs, home-manager) rather than maintaining local forks or complex overrides.
- **Naming Conventions**: Use descriptive, snake_case names for options and module files, adhering to common nixpkgs conventions.
