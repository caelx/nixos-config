{ config, lib, ... }:

let
  cfg = config.myOptions.autoUpgrade;
in
{
  options.myOptions.autoUpgrade = {
    enable = lib.mkEnableOption "automated system upgrades";
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      flake = "git+ssh://git@github.com/caelx/nixos-config.git?ref=main";
      flags = [
        "--update-input" "nixpkgs"
        "--commit-lock-file"
      ];
      dates = "04:00";
      randomizedDelaySec = "45min";
      allowReboot = false;
    };
  };
}
