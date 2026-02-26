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
    ".config/inshellisense/config.json" = {
      text = builtins.toJSON {
        shell = "fish";
        showHelp = true;
        completionMode = "shell";
      };
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

      # Source SSH agent environment if it exists
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

  home.activation = {
    sshConfigD = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/.ssh/conf.d
      $DRY_RUN_CMD chmod $VERBOSE_ARG 0700 $HOME/.ssh/conf.d
    '';
  };

  # SSH Agent
  services.ssh-agent.enable = true;

  systemd.user.services.ssh-agent.Service = {
    ExecStart = lib.mkForce "${pkgs.openssh}/bin/ssh-agent -D -a /run/user/1000/ssh-agent -t 15m";
    ExecStartPre = "-${pkgs.coreutils}/bin/rm -f /run/user/1000/ssh-agent";
    ExecStartPost = let
      script = pkgs.writeShellScript "ssh-agent-post-start" ''
        ${pkgs.coreutils}/bin/mkdir -p $HOME/.config
        # Get socket from process arguments
        # We use $1 which is passed as $MAINPID
        ARGS=$(${pkgs.procps}/bin/ps -p $1 -o args=)
        SOCK=$(echo "$ARGS" | ${pkgs.gnugrep}/bin/grep -oP '(?<=-a\s)\S+')
        
        if [ -n "$SOCK" ]; then
          echo "set -gx SSH_AUTH_SOCK $SOCK;" > $HOME/.config/ssh-agent.env
          echo "set -gx SSH_AGENT_PID $1;" >> $HOME/.config/ssh-agent.env
        else
          echo "Could not find socket in ssh-agent arguments: $ARGS" >&2
          exit 1
        fi
      '';
    in "${script} $MAINPID";
  };

  # SSH Client Configuration
  programs.ssh = {
    enable = true;
    includes = [ "conf.d/*" ];
    matchBlocks = {
      "*" = {
        user = "cael";
        identityFile = "~/.ssh/id_ed25519";
        forwardAgent = true;
        compression = true;
        serverAliveInterval = 60;
        serverAliveCountMax = 30;
        controlMaster = "auto";
        controlPath = "~/.ssh/+%h-%p-%r";
        controlPersist = "5m";
        extraOptions = {
          "AddKeysToAgent" = "yes";
          "StrictHostKeyChecking" = "accept-new";
          "HashKnownHosts" = "no";
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
