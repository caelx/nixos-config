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
    git-ignore
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
      cat = "bat --style plain --paging never";
      fd = "fd --follow";
      gi = "git-ignore";
      ll = "eza -lha --group-directories-first --icons=never";
      ls = "eza";
      rg = "rga";
      tree = "eza --tree";
      reload = "clear; exec fish";
      vissh = "nvim ~/.ssh/config";
      j = "z";
      run = ",";
    };
    functions = {
      fish_greeting = {
        description = "Ghostship Welcome Banner";
        body = ''
          if type -q fastfetch
            fastfetch --structure "Title:Separator:OS:Host:Kernel:Uptime:Packages:Shell:Terminal:CPU:GPU:Memory:Swap:Disk:LocalIp:Battery:Break:Colors"
          end
          set_color normal
        '';
      };
      __ghostship_autols_hook = {
        description = "Auto ls on directory change";
        onEvent = "fish_postexec";
        body = ''
          if status is-interactive
            if not set -q __ghostship_last_pwd
              set -g __ghostship_last_pwd "$PWD"
            end

            if test "$__ghostship_last_pwd" != "$PWD"
              set -g __ghostship_last_pwd "$PWD"
              echo ""
              eza --group-directories-first --icons=never
            end
          end
        '';
      };
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
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      { name = "sponge"; src = pkgs.fishPlugins.sponge.src; }
      { name = "puffer"; src = pkgs.fishPlugins.puffer.src; }
      { name = "colored-man-pages"; src = pkgs.fishPlugins.colored-man-pages.src; }
    ];
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ./config/starship.toml);
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # SSH Agent
  services.ssh-agent.enable = true;

  # SSH Client Configuration
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    compression = true;
    controlMaster = "auto";
    controlPath = "~/.ssh/+%h-%p-%r";
    controlPersist = "5m";
    forwardAgent = true;
    serverAliveCountMax = 30;
    serverAliveInterval = 60;

    matchBlocks = {
      "*" = {
        user = "cael";
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          "GSSAPIAuthentication" = "no";
          "StrictHostKeyChecking" = "accept-new";
        };
      };
    };
  };

  # Git configuration
  programs.git = {
    enable = true;
    lfs.enable = true;
  };
}
