# Gemini Instructions: Unified NixOS Configuration Repository

This repository manages a diverse fleet of NixOS systems. These instructions guide your interactions and implementation strategies for this project.

## Systems & Hardware

### armored-armadillo
- **Purpose**: Dedicated emulation-focused NixOS PC.
- **Hardware**: Minisforum Neptune HX100G.
    - **CPU**: AMD Ryzen 7 7840HS (8 Cores/16 Threads, up to 5.1 GHz, 4nm).
    - **GPU (Integrated)**: AMD Radeon 780M.
    - **GPU (Dedicated)**: AMD Radeon RX 6650M (8GB GDDR6, up to 100W TDP).
    - **RAM**: Supports up to 64GB DDR5 (5600MHz).
    - **Storage**: Dual M.2 2280 PCIe 4.0 SSD slots.
    - **Networking**: 1x RJ45 2.5 Gigabit Ethernet.
    - **WiFi/Bluetooth**: AMD RZ616 (MediaTek MT7922) Wi-Fi 6E & Bluetooth 5.2/5.3.
- **Optimization Strategy**: 
    - Configuration should be optimized for emulation (e.g., low-latency input, optimized Vulkan/OpenGL performance).
    - **Bluetooth Tuning**: The AMD RZ616 (MT7922) requires careful power management on Linux. Disable USB autosuspend for `btusb` and consider disabling ASPM for `mt7921e` if connection drops occur.
    - Support both production hardware (AMD) and development environments (Hyper-V/Gallium) using conditional logic or specialisations.

### launch-octopus
- **Purpose**: Primary WSL2 development environment on Windows 11.
- **Integration**: Deep WSL2-to-Windows integration (notifications, file sharing).

## Core Mandates
- **Modular Design**: Keep hardware-specific logic in `hosts/` and shared logic in `modules/`.
- **Reproducibility**: Ensure all configurations are declarative and reproducible.
- **Security**: Manage all sensitive data through `sops-nix`.
- **Documentation**: Provide inline rationale for non-trivial Nix expressions.
