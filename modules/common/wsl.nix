{ pkgs, ... }:

{
  # WSL-specific networking tweaks
  # Disable systemd-resolved to let WSL manage /etc/resolv.conf
  services.resolved.enable = false;

  # Explicitly ensure we are not using networkd in WSL as per user preference
  networking.useNetworkd = false;
  systemd.network.enable = false;

  # WSL-specific integration
  wsl = {
    enable = true;
    interop.register = true;
    wslConf = {
      automount.enabled = true;
      interop.enabled = true;
    };
  };

  # Share USERPROFILE from Windows to WSL and translate the path (/p)
  # This makes $USERPROFILE available in WSL as /mnt/c/Users/<user>
  environment.variables.WSLENV = "USERPROFILE/p";

  environment.systemPackages = [
    # Allows opening files and directories in Windows applications
    # e.g., 'wsl-open .' opens the current folder in Windows Explorer
    pkgs.wsl-open
  ];

  # Activation script to create ~/win-home symlink for the nixos user
  system.activationScripts.wslHomeSymlink = {
    text = ''
      # Note: Activation scripts run as root, but we want to create the link for the 'nixos' user
      # We need to get the USERPROFILE from the environment if possible,
      # but WSLENV variables might not be available here.
      # As a fallback, we can use powershell.exe to detect it.

      WSL_USER="nixos"
      USER_HOME="/home/$WSL_USER"

      if [ -d "$USER_HOME" ]; then
        # Use PowerShell to get the Windows username and construct the home path
        WIN_USER=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command '$env:UserName' 2>/dev/null | tr -d '\r')

        if [ -n "$WIN_USER" ]; then
          WIN_HOME="/mnt/c/Users/$WIN_USER"

          if [ -n "$WIN_USER" ] && [ -d "$WIN_HOME" ]; then
            echo "Creating symlink $USER_HOME/win-home -> $WIN_HOME"
            ln -sf "$WIN_HOME" "$USER_HOME/win-home"
            chown -h $WSL_USER:nixos "$USER_HOME/win-home"
          fi
        fi
      fi
    '';
    deps = [ "users" ];
  };
}
