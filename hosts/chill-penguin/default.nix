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

  # 16k Page Size Support
  # The apple-silicon kernel already defaults to 16k if configured correctly
  # but we ensure the user-space is compatible.
  
  # Networking
  networking.hostName = "chill-penguin";
  networking.networkmanager.enable = true;

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
