{ inputs, pkgs, ... }:

{
  imports = [
    ./automation.nix
    ./user-nixos.nix
    ./users.nix
    ./gemini.nix
  ];

  # Core Nix Settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    warn-dirty = false;
    # Optimize for large downloads
    download-buffer-size = 134217728; # 128MB
    max-jobs = "auto";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowAliases = false;

  environment.variables = {
    NIXPKGS_ALLOW_ALIASES = "0";
  };

  # Common System Packages
  environment.systemPackages = with pkgs; [
    # Tech Stack Tools
    inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.nh
    nvd         # Nix Visual Diff
    comma       # Run any binary from nixpkgs

    # Essential CLI tools
    git
    neovim
    curl
    wget
    htop

    # Standard Utilities
    _7zz
    fd
    fzf
    ldns # Provides drill

    # Provide dig as a wrapper around drill system-wide
    (pkgs.writeShellScriptBin "dig" ''exec ${pkgs.ldns}/bin/drill "$@"'')

    # Provide vi and vim as wrappers around neovim system-wide
    (pkgs.writeShellScriptBin "vi" ''exec ${pkgs.neovim}/bin/nvim "$@"'')
    (pkgs.writeShellScriptBin "vim" ''exec ${pkgs.neovim}/bin/nvim "$@"'')
  ];

  # Enable nix-ld for dynamically linked binaries (e.g., VS Code Server)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat
  ];

  # Fast, persistent development environment loading
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Set your time zone.
  time.timeZone = "UTC"; # User should override this in host config if needed

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
}
