{ ... }:

{
  # WSL-specific networking tweaks
  # Disable systemd-resolved to let WSL manage /etc/resolv.conf
  services.resolved.enable = false;

  # Explicitly ensure we are not using networkd in WSL as per user preference
  networking.useNetworkd = false;
  systemd.network.enable = false;

  # WSL-specific integration
  wsl = {
    wslConf = {
      automount.enabled = true;
      interop.enabled = true;
    };
  };

  # Share USERPROFILE from Windows to WSL and translate the path (/p)
  # This makes $USERPROFILE available in WSL as /mnt/c/Users/<user>
  environment.variables.WSLENV = "USERPROFILE/p";

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
          
          # Translate Windows path to Linux path using wslpath
          if [ -d "$WIN_HOME" ]; then
            LINUX_WIN_HOME=$(/run/current-system/sw/bin/wslpath "$WIN_HOME" 2>/dev/null)
            
            if [ -n "$LINUX_WIN_HOME" ] && [ -d "$LINUX_WIN_HOME" ]; then
              echo "Creating symlink $USER_HOME/win-home -> $LINUX_WIN_HOME"
              ln -sf "$LINUX_WIN_HOME" "$USER_HOME/win-home"
              chown -h $WSL_USER:nixos "$USER_HOME/win-home"
            fi
          fi
        fi
      fi
    '';
    deps = [ "users" ];
  };
}
