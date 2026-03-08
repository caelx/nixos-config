{ config, lib, pkgs, modulesPath, ... }:

{
  # Hardware: Minisforum Neptune HX100G
  # CPU: AMD Ryzen 7 7840HS (8 Cores/16 Threads, up to 5.1 GHz, 4nm)
  # GPU (Integrated): AMD Radeon 780M
  # GPU (Dedicated): AMD Radeon RX 6650M (8GB GDDR6, up to 100W TDP)
  # RAM: Supports up to 64GB DDR5 (5600MHz)
  # Networking: 1x RJ45 2.5 Gigabit Ethernet
  # WiFi/Bluetooth: AMD RZ616 (MediaTek MT7922)
  # Tuning Note: For Bluetooth stability, disable USB autosuspend for btusb.
  # For WiFi stability, disable ASPM for mt7921e if needed.
  
  # Placeholder for hardware configuration
  # Conditional logic for AMD vs Gallium will be implemented here later.
  
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  fileSystems."/" =
    { device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
