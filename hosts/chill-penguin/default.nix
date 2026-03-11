{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/default.nix
    ../../modules/common/secrets.nix
    # Apple Silicon support is provided via the nixos-apple-silicon module in flake.nix
  ];

  # Apple Silicon Specifics
  hardware.asahi = {
    # Headless setup for Mac Studio
    useExperimentalGPUDriver = false; # Keep false for headless reliability
    setupAsahiSound = false; # Headless
    withRust = true; # Required for newer kernels
  };

  # Binary Cache for Apple Silicon
  nix.settings = {
    substituters = [ "https://nixos-apple-silicon.cachix.org" ];
    trusted-public-keys = [ "nixos-apple-silicon.cachix.org-1:99u9ab+GY9ST64WcjF0QMnqKSCDasA/6bGuD6uQB9vY=" ];
  };

  # Performance
  zramSwap.enable = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false; # Apple Silicon doesn't support this via EFI

  # 16k Page Size Support
  # The apple-silicon kernel already defaults to 16k if configured correctly
  # but we ensure the user-space is compatible.
  
  # Networking
  networking.hostName = "chill-penguin";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd"; # Recommended for Apple Silicon
  networking.wireless.iwd.enable = true;

  # Headless Optimizations
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # User management (handled via modules/common/users.nix)
  # But we ensure cael is present
  users.users.cael = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "render" ];
    # Keys should be managed via sops or common users module
  };

  # State version
  system.stateVersion = "25.11";
}
