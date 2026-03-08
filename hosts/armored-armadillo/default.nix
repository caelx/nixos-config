{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/default.nix
    ../../modules/common/secrets.nix
  ];

  # Hostname
  networking.hostName = "armored-armadillo";

  # State version
  system.stateVersion = "25.11";
}
