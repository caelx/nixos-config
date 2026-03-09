{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/default.nix
    ../../modules/common/secrets.nix
  ];

  # Hostname
  networking.hostName = "armored-armadillo-dev";

  # Enable Hyprland (Testing in VM)
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Graphics (Mesa)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];

  # Basic input settings
  services.libinput.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Hyper-V Guest Services
  virtualisation.hypervGuest.enable = true;

  # State version
  system.stateVersion = "25.11";
}
