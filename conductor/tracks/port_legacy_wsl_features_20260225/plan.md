# Implementation Plan: Port Legacy WSL Features

This plan outlines the steps to port features from the legacy `old/wsl-config` (Ansible) repository to the new NixOS flake configuration, including WSL SMB mounting, standard packages, SSH configuration, and Fish shell setup.

## Phase 1: Secrets and Base Packages [checkpoint: 39b94b4]
- [x] Task: Configure sops-nix for SMB credentials (61f45b0)
    - [x] Add `smb-user` and `smb-pass` to `secrets.yaml`.
    - [x] Configure `modules/common/secrets.nix` to decrypt these secrets.
- [x] Task: Audit and add standard packages (229a59f)
    - [x] Verify `7zip`, `bat`, `cifs-utils`, `direnv`, `fastfetch`, `fd`, `eza`, `ripgrep-all`, `starship`, `zoxide` are in `modules/common/default.nix`.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Secrets and Base Packages' (Protocol in workflow.md) (39b94b4)

## Phase 2: SSH Configuration
- [x] Task: Enable ssh-agent user service (823b334)
    - [x] Configure `programs.ssh.startAgent = true;` or equivalent user-level systemd service in `home/nixos.nix`.
- [x] Task: Declarative SSH client configuration (823b334)
    - [x] Port settings from `old/wsl-config/ansible/roles/ssh/tasks/main.yml` to `home-manager.users.nixos.programs.ssh`.
    - [x] Include `ControlMaster`, `Compression`, and `IdentityFile` settings.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: SSH Configuration' (Protocol in workflow.md)

## Phase 3: WSL SMB Mounting (mount-z)
- [ ] Task: Implement mount-z systemd service
    - [ ] Create a NixOS module or script to handle the mount logic from `mount-z.sh`.
    - [ ] Ensure the service depends on network availability and successfully decrypted secrets.
    - [ ] Configure the mount point `/mnt/z`.
- [ ] Task: Verify WSL mounting
    - [ ] Test that the drive mounts correctly when accessible.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: WSL SMB Mounting' (Protocol in workflow.md)

## Phase 4: Fish Shell Implementation
- [ ] Task: Set Fish as default shell
    - [ ] Configure `users.users.nixos.shell = pkgs.fish;`.
- [ ] Task: Port Fish configurations
    - [ ] Migrate aliases and functions from `old/wsl-config/ansible/roles/fish/files/conf.d/` to Home Manager.
- [ ] Task: Configure Starship prompt
    - [ ] Enable `programs.starship` in Home Manager and port `starship.toml` settings.
- [ ] Task: Manage Fish plugins
    - [ ] Use `programs.fish.plugins` in Home Manager to install `autopair`, `sponge`, `puffer-fish`, and `fish-colored-man`. (Skipping `gitignore` and `autovenv` as requested).
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Fish Shell Implementation' (Protocol in workflow.md)
