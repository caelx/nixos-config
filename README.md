# Unified NixOS Configuration Fleet

A robust, modular, and reproducible NixOS configuration repository managing a diverse fleet of systems—replacing legacy Ansible-based infrastructure with a modern, declarative Nix-native approach.

## 🚀 Vision
To create an identical state across personal workstations, servers, and embedded devices using Nix Flakes and Home Manager, ensuring absolute reproducibility and seamless platform integration (especially for WSL2).

## 🛠 Tech Stack

### Core Ecosystem
- **Nix & Nix Flakes**: Dependency management and standardized outputs.
- **NixOS**: The primary operating system.
- **Home Manager**: Declarative user environment and dotfile management.
- **sops-nix**: Secure secret management using Mozilla SOPS (age/gpg).

### Development & Shell
- **Fish Shell**: Primary interactive shell with a rich plugin ecosystem.
- **Starship**: Cross-shell prompt for a consistent visual experience.
- **devenv**: Declarative development environments.
- **direnv & nix-direnv**: Automatic shell activation.
- **Inshellisense**: IDE-style autocomplete for the CLI.
- **Modern CLI Utils**: `eza` (ls), `bat` (cat), `fd` (find), `zoxide` (cd), `fzf` (search), `nh` (nix helper).

## 💻 Systems
- **launch-octopus**: Primary WSL2 development environment on Windows 11.

## ✨ Key Features

### WSL2 Integration
- **notify-send Bridge**: Forwards Linux notifications to the Windows Action Center with native branding.
- **wsl-open**: Seamlessly open Linux files/directories in Windows applications.
- **win-home Symlink**: Direct access to your Windows user profile at `~/win-home`.
- **WSLENV Integration**: Shared environment variables between host and guest.

### Security
- **Secrets Management**: Encrypted `secrets.yaml` integrated directly into NixOS modules via `sops-nix`.

## 📖 Usage

### Apply Configuration
To rebuild the system and switch to the latest configuration:
```bash
sudo nixos-rebuild switch --flake .#launch-octopus
```

### Manage Secrets
To edit encrypted secrets (requires appropriate keys):
```bash
# Using the helper alias if defined, or sops directly
sops secrets.yaml
```

### Notifications
Standard Linux notification commands are automatically forwarded to Windows:
```bash
notify-send "Task Complete" "The build has finished."
```

## 📂 Structure
- `hosts/`: Hardware-specific configurations for each machine.
- `modules/`: Shared system-level NixOS modules (common, services, etc.).
- `home/`: User-level Home Manager configurations.
- `conductor/`: Project management, specifications, and implementation plans.
