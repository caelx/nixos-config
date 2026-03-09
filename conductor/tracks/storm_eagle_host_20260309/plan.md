# Implementation Plan: Add Host `storm-eagle` (Mac Studio Asahi Linux)

## Phase 1: Foundation and Global Configuration
Establish the base host configuration and common tools.

- [ ] **Task: Add `dasel` to common system packages**
    - [ ] Update `modules/common/default.nix` to include `dasel`.
- [ ] **Task: Initialize `storm-eagle` host configuration**
    - [ ] Create `hosts/storm-eagle/default.nix` with Asahi Linux basics and headless settings.
    - [ ] Create placeholder `hosts/storm-eagle/hardware-configuration.nix`.
    - [ ] Add `storm-eagle` to `flake.nix` outputs.
- [ ] **Task: Define Static UID/GID Mapping and Shared Group**
    - [ ] **Register all service users and groups in the 'Fleet ID Registry' in `conductor/product-guidelines.md`.**
    - [ ] Create a central mapping for all service users in a new module or within `modules/common/users.nix`.
    - [ ] Create the `media-data` shared group.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Foundation' (Protocol in workflow.md)

## Phase 2: `self-hosted` Module Structure
Set up the modular directory structure for self-hosted services.

- [ ] **Task: Create `modules/self-hosted` structure**
    - [ ] Create `modules/self-hosted/default.nix`.
    - [ ] Create `modules/self-hosted/common.nix` for shared OCI container settings and user management.
- [ ] **Task: Establish Data Directory Layout**
    - [ ] Implement an activation script in `modules/self-hosted/common.nix` to ensure `/srv/apps/` exists with correct permissions.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: self-hosted Structure' (Protocol in workflow.md)

## Phase 3: Core Infrastructure and Networking
Implement the base services and the internal network.

- [ ] **Task: Implement Internal OCI Network**
    - [ ] Define a bridge network for all self-hosted containers.
- [ ] **Task: Port Core Services**
    - [ ] Implement `gluetun` module in `modules/self-hosted/services/gluetun.nix`.
    - [ ] Implement `cloudflared` module.
    - [ ] Implement `homepage` and `muximux` modules.
- [ ] **Task: Implement SOPS Secrets Integration**
    - [ ] Define the necessary secrets for core services in `secrets.yaml`.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Core Infrastructure' (Protocol in workflow.md)

## Phase 4: Database Stack
Implement isolated database containers for dependent services.

- [ ] **Task: Implement Database Modules**
    - [ ] Create reusable database container modules (MariaDB, PostgreSQL).
    - [ ] Instantiate `romm-db`, `booklore-db`, and `warracker-db`.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Database Stack' (Protocol in workflow.md)

## Phase 5: Media Acquisition and Management
Port the download and indexing suite.

- [ ] **Task: Implement VPN-Routed Downloaders**
    - [ ] Port `qbittorrent` and `nzbget` with VPN routing and `dasel` merging.
- [ ] **Task: Port *Arr Suite**
    - [ ] Port `prowlarr`, `sonarr`, `radarr`, `bazarr`.
    - [ ] Implement `dasel` merging for `config.xml`.
- [ ] **Task: Port Management Utilities**
    - [ ] Port `recyclarr`, `huntarr`, `flaresolverr`.
- [ ] Task: Conductor - User Manual Verification 'Phase 5: Media Acquisition' (Protocol in workflow.md)

## Phase 6: Streaming and Content
Port media servers and library managers.

- [ ] **Task: Port Plex Stack**
    - [ ] Port `plex` with `Preferences.xml` merging.
    - [ ] Port `tautulli` and `plex-auto-languages`.
- [ ] **Task: Port Library Managers**
    - [ ] Port `romm` and `booklore`.
    - [ ] Port `metube`.
- [ ] Task: Conductor - User Manual Verification 'Phase 6: Streaming and Content' (Protocol in workflow.md)

## Phase 7: Utility, Automation, and 3D
Port the remaining specialized services.

- [ ] **Task: Port Home Automation**
    - [ ] Port `homeassistant` with `configuration.yaml` merging.
    - [ ] Port `windmill` (replaces activepieces).
- [ ] **Task: Port 3D and Utility**
    - [ ] Port `manyfold`, `PrintGuard`, `it-tools`, `bentopdf`.
- [ ] **Task: Port Remaining Utilities**
    - [ ] Port `syncthing`, `zerobyte`, `warracker`, `searxng`, `convertx`, `ladder`, `fileflows`.
- [ ] Task: Conductor - User Manual Verification 'Phase 7: Utility and Automation' (Protocol in workflow.md)

## Phase 8: Final Integration and Validation
Final checks and inter-service connectivity.

- [ ] **Task: Verify Inter-Container Connectivity**
    - [ ] Ensure all services can communicate over the bridge network.
    - [ ] Verify `cloudflared` can reach the intended internal services.
- [ ] **Task: Perform Global Build Check**
    - [ ] Ensure `nixos-rebuild build --flake .#storm-eagle` passes.
- [ ] Task: Conductor - User Manual Verification 'Phase 8: Final Integration' (Protocol in workflow.md)
