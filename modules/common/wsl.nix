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
    
    # Try to find Windows Terminal info
    \$wt = Get-AppxPackage -Name Microsoft.WindowsTerminal
    \$iconPath = \$null
    \$aumid = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
    
    if (\$wt) {
        \$aumid = "\$(\$wt.PackageFamilyName)!App"
        \$iconPath = Get-ChildItem -Path "\$(\$wt.InstallLocation)\Images" -Include "Square150x150Logo.scale-200.png", "Square44x44Logo.targetsize-256.png", "terminal_contrast-white.ico" -Recurse | Select-Object -First 1 -ExpandProperty FullName
    }

    # Use modern ToastGeneric template
    \$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    \$xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text id='1'/><text id='2'/></binding></visual><audio src='ms-winsoundevent:Notification.Default'/></toast>")
    
    \$xml.GetElementsByTagName('text').Item(0).InnerText = '$TITLE'
    \$xml.GetElementsByTagName('text').Item(1).InnerText = @'
$MESSAGE
'@

    if (\$iconPath -and (Test-Path \$iconPath)) {
        \$binding = \$xml.GetElementsByTagName('binding').Item(0)
        \$image = \$xml.CreateElement('image')
        \$image.SetAttribute('src', \$iconPath)
        \$image.SetAttribute('placement', 'appLogoOverride')
        \$image.SetAttribute('hint-crop', 'circle')
        \$binding.AppendChild(\$image) > \$null
    }
    
    \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(\$aumid).Show(\$toast)
} catch {}
EOF

      # Convert path for Windows
      WIN_PATH=$(wslpath -w "$PS_SCRIPT")
      
      # Run PowerShell in background
      /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PATH" &
      
      # Cleanup temp file
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
