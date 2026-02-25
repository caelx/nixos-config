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
}
