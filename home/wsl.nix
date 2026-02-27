{ config, lib, pkgs, ... }:

{
  programs.fish = {
    interactiveShellInit = ''
      # Initialize inshellisense
      test -f ~/.inshellisense/fish/init.fish && source ~/.inshellisense/fish/init.fish

      # Source SSH agent environment if it exists
      if test -f ~/.config/ssh-agent.env
        source ~/.config/ssh-agent.env
      end

      # Windows Notification Hooks
      function __win_notify_postexec --on-event fish_postexec
          set -l last_status $status
          set -l duration_ms $CMD_DURATION
          set -l duration_s (math "scale=0; $duration_ms / 1000")
          
          # Only notify for commands that take longer than 3 seconds to avoid spam
          if test $duration_s -ge 3
              set -l msg "Command: $argv[1]"
              if test $last_status -ne 0
                  set msg "$msg (failed with $last_status)"
              end
              
              set -l title "Command Finished"
              if test $duration_s -ge 180
                  set title "Long Task Finished"
                  set msg "$msg (took (math "scale=1; $duration_s / 60")m)"
              end
              
              set -l tab_title (hostname):(prompt_pwd)
              win-notify "$msg" "$title" "$tab_title"
          end
      end
    '';
    functions = {
      fish_title = {
        body = ''
          set -l cmd $argv[1]
          set -l tab_title (hostname):(prompt_pwd)
          # Check for specific titles that require action
          if string match -q "*Action Required*" "$cmd"
              win-notify "Terminal needs attention: $cmd" "Action Required" "$tab_title"
          else if string match -q "*Ready*" "$cmd"
              win-notify "Terminal is ready" "Status Update" "$tab_title"
          end
          echo $cmd
        '';
      };
      sudo = {
        description = "Wrap sudo to notify on potential password prompt";
        body = ''
          if status is-interactive
              set -l tab_title (hostname):(prompt_pwd)
              win-notify "Sudo password may be requested" "Action Required" "$tab_title"
          end
          command sudo $argv
        '';
      };
    };
    shellAliases = {
      open = "wsl-open";
    };
  };

  # SSH Agent with WSL-specific systemd service
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
}
