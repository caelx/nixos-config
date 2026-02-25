{ ... }:

{
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
}
