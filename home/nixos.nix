{ config, lib, pkgs, ... }:

{
  home.username = "nixos";
  home.homeDirectory = "/home/nixos";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # Add user-specific packages here
    bat
    eza
    fd
    ripgrep
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".nix-profile" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.local/state/nix/profiles/home-manager";
    };
  };

  # You can also manage environment variables through 'home.sessionVariables'.
  # If you don't want to manage your shell through Home Manager, then you
  # have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/nixos/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Activation script for one-time home directory ownership fix
  home.activation.homeChown = lib.hm.dag.entryAfter ["writeBoundary"] ''
    SENTINEL="${config.home.homeDirectory}/.local/state/nix/home_chown.done"
    if [ ! -f "$SENTINEL" ]; then
      echo "Running one-time home directory chown..."
      # This runs as the user. If root-owned files are an issue, sudo might be needed
      # but we try standard chown first as requested.
      chown -R ${config.home.username}:${config.home.username} ${config.home.homeDirectory}
      mkdir -p $(dirname "$SENTINEL")
      touch "$SENTINEL"
    fi
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Git configuration
  programs.git = {
    enable = true;
  };
}
