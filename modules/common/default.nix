{ pkgs, ... }:

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
    # Optimize for large downloads
    download-buffer-size = 134217728; # 128MB
    max-jobs = "auto";
  };

  # Common System Packages
  environment.systemPackages = with pkgs; [
    # Tech Stack Tools
    nh          # Nix Helper
    nvd         # Nix Visual Diff
    comma       # Run any binary from nixpkgs
    direnv      # Automatic environment loading
    nix-direnv  # Nix integration for direnv

    # Essential CLI tools
    git
    neovim
    curl
    wget
    htop

    # Standard Utilities
    _7zz
    bat
    cifs-utils
    fastfetch
    fd
    eza
    ripgrep-all
    starship
    zoxide
    ldns # Provides drill

    # Provide dig as a wrapper around drill system-wide
    (pkgs.writeShellScriptBin "dig" ''exec ${pkgs.ldns}/bin/drill "$@"'')

    # Provide vi and vim as wrappers around neovim system-wide
    (pkgs.writeShellScriptBin "vi" ''exec ${pkgs.neovim}/bin/nvim "$@"'')
    (pkgs.writeShellScriptBin "vim" ''exec ${pkgs.neovim}/bin/nvim "$@"'')
  ];

  # Enable nix-ld for dynamically linked binaries (e.g., VS Code Server)
  programs.nix-ld.enable = true;

  # Set your time zone.
  time.timeZone = "UTC"; # User should override this in host config if needed

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
}
