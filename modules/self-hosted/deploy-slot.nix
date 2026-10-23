# The deploy slot: one record of who may activate this host, so two deploys
# never race and nobody relays "the slot is free" by message.
# `ghostship-deploy-slot` (scripts/deploy-slot) keeps the record in a
# root-only state directory, `scripts/activate-host` refuses an activation
# whose caller does not hold the slot, and `agent deploy slot` drives it over
# SSH. An unattended switch would bypass the slot, so the automatic upgrade
# must be off on a host that uses it.
{ config, lib, pkgs, ... }:

let
  cfg = config.ghostship.deploySlot;
  tool = pkgs.writeShellApplication {
    name = "ghostship-deploy-slot";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${../../scripts/deploy-slot} "$@"
    '';
  };
in
{
  options.ghostship.deploySlot.enable = lib.mkEnableOption
    "Require the deploy slot for every activation of this host";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ tool ];
    # The tool creates the directory too; tmpfiles keeps its mode root-only.
    systemd.tmpfiles.rules = [ "d /var/lib/ghostship-deploy-slot 0700 root root -" ];

    assertions = [
      {
        assertion = !config.system.autoUpgrade.enable;
        message = ''
          ghostship.deploySlot is enabled, so system.autoUpgrade must be off: the
          unattended nixos-upgrade switch activates the host outside the deploy
          slot and its gates. Deploy with `agent deploy run` instead.
        '';
      }
    ];
  };
}
