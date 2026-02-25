# Specification: WSL2 Features Integration

## Overview
Enhance the NixOS WSL2 environment with improved integration features. This track focuses on seamless interoperability, file access via WSLENV, and system service sharing (clipboard, sound).

## Functional Requirements
1.  **Directory Navigation (Windows Explorer):**
    - Install `wsl-open`.
    - Create a shell alias `open` -> `wsl-open`.
2.  **WSLENV Path Sharing:**
    - Configure `WSLENV` to share the Windows `USERPROFILE` path with WSL.
    - Use the translated path to create a symlink `~/win-home` pointing to the Windows user directory.
3.  **System Integration:**
    - **Clipboard:** Enable clipboard sharing.
    - **Sound:** Configure PulseAudio for sound support to Windows.
    - **Docker:** Ensure compatibility with Docker Desktop integration.

## Acceptance Criteria
- `$USERPROFILE` is available in the WSL environment and points to the translated Linux path (e.g., `/mnt/c/Users/james`).
- `open .` opens the current directory in Windows Explorer.
- `~/win-home` symlink is functional.
- Clipboard and Sound are working.
