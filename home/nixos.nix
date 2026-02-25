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
    # Ported from old config
    p7zip
    cifs-utils
    fastfetch
    ldns
    python3Packages.pipx
    ripgrep-all
    nodejs
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

  # Shell Configuration
  programs.bat.enable = true;
  programs.fd.enable = true;
  programs.ripgrep.enable = true;

  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    icons = "auto";
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      # Core Aliases
      c = "cat";
      cat = "bat --style plain --paging never";
      fd = "fd --follow";
      l = "eza --color=always -h --group-directories-first -p";
      ld = "fd --type directory --max-depth 1";
      lda = "fd --type directory";
      lf = "fd --type file --max-depth 1";
      lfa = "fd --type file";
      ll = "eza -lha --group-directories-first --icons=never";
      ls = "eza";
      rg = "rg"; # or rga if we use ripgrep-all
      tree = "eza --tree";
      reload = "clear; exec fish";
      vissh = "nvim ~/.ssh/config";
    };
    functions = {
      rmssh = {
        description = "Cleanup SSH multiplexing sockets";
        body = ''
          set -l files $HOME/.ssh/+*
          if set -q files[1]
              rm $files
          end
          pkill -9 -f "$HOME/.ssh/+*" || true
        '';
      };
    };
    plugins = [
      # Plugins from old config
      { name = "gitignore"; src = pkgs.fishPlugins.gitignore.src; }
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      { name = "sponge"; src = pkgs.fishPlugins.sponge.src; }
      { name = "puffer"; src = pkgs.fishPlugins.puffer.src; }
      { name = "colored-man-pages"; src = pkgs.fishPlugins.colored-man-pages.src; }
    ];
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Git configuration
  programs.git = {
    enable = true;
    lfs.enable = true;
  };
}
