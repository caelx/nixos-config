# The deploy slot on chill-penguin, as the host actually evaluates it.
#
# Every activation of the host needs the deploy slot, so the slot tool must be
# installed with its root-only state directory, and no unattended switch may
# bypass it: the automatic upgrade must be off, and turning it back on must
# fail the evaluation instead of switching the host outside the slot.
let
  flake = builtins.getFlake (toString ../.);
  base = flake.nixosConfigurations.chill-penguin;
  inherit (base.pkgs) lib;
  config = base.config;
  packageNames = map (package: package.name or "") config.environment.systemPackages;
  # The same host with the automatic upgrade turned back on.
  upgraded = base.extendModules {
    modules = [ { system.autoUpgrade.enable = lib.mkForce true; } ];
  };
  failedAssertions = map (assertion: assertion.message)
    (builtins.filter (assertion: !assertion.assertion) upgraded.config.assertions);
in
assert lib.assertMsg config.ghostship.deploySlot.enable
  "chill-penguin must require the deploy slot for every activation.";
assert lib.assertMsg (!config.system.autoUpgrade.enable)
  "chill-penguin must not run the unattended nixos-upgrade switch: it bypasses the deploy slot.";
assert lib.assertMsg (lib.elem "ghostship-deploy-slot" packageNames)
  "chill-penguin must install ghostship-deploy-slot, the tool `agent deploy slot` runs over SSH.";
assert lib.assertMsg
  (lib.elem "d /var/lib/ghostship-deploy-slot 0700 root root -" config.systemd.tmpfiles.rules)
  "the deploy slot's state directory must be root-only.";
assert lib.assertMsg
  (lib.any (message: lib.hasInfix "system.autoUpgrade must be off" message) failedAssertions)
  "turning the automatic upgrade back on must fail the evaluation while the deploy slot is enabled.";
true
