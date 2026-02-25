{ config, pkgs, ... }:

{
  # Global shell configuration
  programs.fish.enable = true;

  # Common user definition for 'nixos'
  users.users.nixos = {
    isNormalUser = true;
    uid = 1000;
    group = "nixos";
    description = "nixos";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
    hashedPasswordFile = config.sops.secrets.nixos-password.path;
  };

  # Sudo configuration
  security.sudo.extraConfig = ''
    # Require password re-authentication every 15 minutes
    Defaults timestamp_timeout=15
  '';

  users.groups.nixos.gid = 1000;
}
