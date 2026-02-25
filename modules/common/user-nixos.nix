{ pkgs, ... }:

{
  # Global shell configuration
  programs.fish.enable = true;

  # Common user definition for 'nixos'
  users.users.nixos = {
    isNormalUser = true;
    uid = 1000;
    group = "nixos";
    description = "nixos";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };

  users.groups.nixos.gid = 1000;
}
