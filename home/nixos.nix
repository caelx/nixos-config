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
    ripgrep-all
    nodejs
    git-ignore
    starship
    zoxide
    fd
    bat
    cifs-utils
    fastfetch
    eza
    inshellisense
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
    interactiveShellInit = ''
      # Initialize inshellisense
      test -f ~/.inshellisense/fish/init.fish && source ~/.inshellisense/fish/init.fish

      # Source SSH agent environment from custom systemd service
      if test -f ~/.config/ssh-agent.env
        source ~/.config/ssh-agent.env
      end
    '';
    shellAliases = {
      # Core Aliases
      cat = "bat --style plain --paging never";
      fd = "fd --follow";
      gi = "git-ignore";
      ll = "eza -lha --group-directories-first";
      ls = "eza --group-directories-first";
      rg = "rga";
      tree = "eza --group-directories-first --tree";
      reload = "clear; exec fish";
      vissh = "nvim ~/.ssh/config";
      j = "z";
      run = ",";
      open = "wsl-open";
    };
    functions = {
      cd = {
        description = "Change directory and auto-ls";
        body = ''
          builtin cd $argv
          if status is-interactive
            eza --group-directories-first --icons=auto
          end
        '';
      };
      fish_greeting = {
        description = "Ghostship Welcome Banner";
        body = ''
          if type -q fastfetch
            fastfetch --structure "Title:Separator:OS:Host:Kernel:Uptime:Packages:Shell:Terminal:CPU:GPU:Memory:Swap:Disk:LocalIp:Battery:Break:Colors"
          end
          set_color normal
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

  programs.nix-index.enable = true;

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  systemd.user.services.ssh-agent-env-writer = {
    enable = true;
    Unit = {
      Description = "SSH Agent Environment Writer";
      After = [ "default.target" ];
      BindsTo = [ "default.target" ]; # Ensure it stops when user logs out
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = ''
        ${pkgs.gnused}/bin/sed -i '/^set -gx SSH_AGENT_PID/d' ~/.config/ssh-agent.env
        ${pkgs.gnused}/bin/sed -i '/^set -gx SSH_AUTH_SOCK/d' ~/.config/ssh-agent.env
        ${pkgs.openssh}/bin/ssh-agent -c > ~/.config/ssh-agent.env
      '';
      ExecStop = ''
        test -f ~/.config/ssh-agent.env && . ~/.config/ssh-agent.env && ${pkgs.openssh}/bin/ssh-agent -k
        ${pkgs.coreutils}/bin/rm -f ~/.config/ssh-agent.env
      '';
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # SSH Agent
  services.ssh-agent.enable = false;

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
          "StrictHostKeyChecking" = "accept-new";
          "UserKnownHostsFile" = "~/.ssh/known_hosts";
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
