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

    # Windows Notification Bridge
    (pkgs.writeShellScriptBin "win-notify" ''
      MESSAGE="$1"
      TITLE="''${2:-WSL2 Notification}"
      
      # Use a temporary file for the PowerShell script to avoid escaping issues
      PS_SCRIPT=$(mktemp --suffix=.ps1)
      
      cat <<EOF > "$PS_SCRIPT"
\$ErrorActionPreference = 'SilentlyContinue'
try {
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    
    \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    \$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    \$xml.LoadXml(\$template.GetXml())
    
    \$textNodes = \$xml.GetElementsByTagName('text')
    \$textNodes.Item(0).AppendChild(\$xml.CreateTextNode('$TITLE')) > \$null
    \$textNodes.Item(1).AppendChild(\$xml.CreateTextNode(@'
$MESSAGE
'@)) > \$null
    
    \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('WSL2').Show(\$toast)
} catch {}
EOF

      # Convert path for Windows
      WIN_PATH=$(wslpath -w "$PS_SCRIPT")
      
      # Run PowerShell with a timeout to prevent hanging the terminal
      # We use 'timeout' to ensure the WSL side returns, and background it if needed
      /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PATH" &
      
      # Cleanup the temp file after a short delay to ensure PS has read it
      (sleep 5 && rm "$PS_SCRIPT") &
    '')
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
