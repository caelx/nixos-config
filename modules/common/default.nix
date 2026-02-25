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
  ];

  # Set your time zone.
  time.timeZone = "UTC"; # User should override this in host config if needed

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
}
