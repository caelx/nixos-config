{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  redroidLab = pkgs.callPackage ../../packages/redroid-lab { };
  adb = "${pkgs.android-tools}/bin/adb";
  redroidState = "/var/lib/redroid";
  androidDataImage = "${redroidState}/android-data.ext4";
  androidDataMarker = "${redroidState}/android-data.initialized";
  redroidSecrets = "${redroidState}/secrets";
  redroidVsockAuth = "${redroidState}/vsock-auth";
  androidLabConfig = self.nixosConfigurations.android-lab.config;
  t3Home = "/srv/apps/t3code/home";
  t3RedroidConfig = "${t3Home}/.config/redroid";
  t3RedroidBin = "${t3Home}/.local/bin";
  redroidProvision = pkgs.writeShellScript "redroid-provision-runtime" ''
    set -euo pipefail

    secret_dir=${lib.escapeShellArg redroidSecrets}
    t3_config=${lib.escapeShellArg t3RedroidConfig}
    t3_bin=${lib.escapeShellArg t3RedroidBin}
    install -d -m 0750 -o root -g redroid-gateway "$secret_dir"
    install -d -m 0700 -o 3000 -g 3000 "$t3_config"
    install -d -m 0755 -o 3000 -g 3000 "$t3_bin"

    if [ ! -s "$secret_dir/redroid-gateway-token" ]; then
      umask 077
      ${pkgs.openssl}/bin/openssl rand -hex 32 > "$secret_dir/.token.new"
      install -m 0440 -o root -g redroid-gateway \
        "$secret_dir/.token.new" "$secret_dir/redroid-gateway-token"
      rm -f "$secret_dir/.token.new"
    fi

    if [ ! -s "$secret_dir/tls.crt" ] || [ ! -s "$secret_dir/tls.key" ]; then
      rm -f "$secret_dir/.tls.crt.new" "$secret_dir/.tls.key.new"
      ${pkgs.openssl}/bin/openssl req -x509 -newkey ec \
        -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 3650 \
        -subj '/CN=redroid-gateway' \
        -addext 'subjectAltName=DNS:redroid-gateway' \
        -keyout "$secret_dir/.tls.key.new" \
        -out "$secret_dir/.tls.crt.new" >/dev/null 2>&1
      install -m 0440 -o root -g redroid-gateway \
        "$secret_dir/.tls.key.new" "$secret_dir/tls.key"
      install -m 0440 -o root -g redroid-gateway \
        "$secret_dir/.tls.crt.new" "$secret_dir/tls.crt"
      rm -f "$secret_dir/.tls.crt.new" "$secret_dir/.tls.key.new"
    fi

    chown root:redroid-gateway \
      "$secret_dir/redroid-gateway-token" "$secret_dir/tls.crt" "$secret_dir/tls.key"
    chmod 0440 \
      "$secret_dir/redroid-gateway-token" "$secret_dir/tls.crt" "$secret_dir/tls.key"

    install -o 3000 -g 3000 -m 0600 \
      "$secret_dir/redroid-gateway-token" "$t3_config/gateway-token"
    install -o 3000 -g 3000 -m 0644 \
      "$secret_dir/tls.crt" "$t3_config/gateway-ca.crt"
    install -o 3000 -g 3000 -m 0755 \
      ${redroidLab.redroidCtl}/bin/redroidctl "$t3_bin/redroidctl"
  '';
  redroidDataProvision = pkgs.writeShellScript "redroid-provision-data" ''
    set -euo pipefail
    state=${lib.escapeShellArg redroidState}
    image=${lib.escapeShellArg androidDataImage}
    marker=${lib.escapeShellArg androidDataMarker}
    install -d -m 0711 -o root -g root "$state"

    write_marker() {
      local candidate="$marker.new"
      printf 'REDROID_DATA\n' > "$candidate"
      chmod 0400 "$candidate"
      mv -f "$candidate" "$marker"
      ${pkgs.coreutils}/bin/sync -f "$state"
    }

    if [ -e "$image" ] || [ -L "$image" ]; then
      [ -f "$image" ] && [ ! -L "$image" ] || {
        echo "Android data path is not a regular file; refusing replacement" >&2
        exit 1
      }
      label=$(${pkgs.util-linux}/bin/blkid -p -s LABEL -o value "$image" 2>/dev/null || true)
      [ "$label" = REDROID_DATA ] || {
        echo "Android data image has no REDROID_DATA label; refusing implicit reset" >&2
        exit 1
      }
      chown root:redroid-vm-data "$image"
      chmod 0660 "$image"
      if [ -e "$marker" ]; then
        [ -f "$marker" ] && [ ! -L "$marker" ] && \
          [ "$(<"$marker")" = REDROID_DATA ] || {
          echo "Android data initialization marker is invalid" >&2
          exit 1
        }
      else
        # Preserve a valid existing disk during migration from autoCreate.
        write_marker
      fi
      exit 0
    fi

    if [ -e "$marker" ]; then
      set -- "$state"/quarantine/android-data-*
      if [ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ]; then
        # The lifecycle controller will restore the sole quarantined image
        # before the VM starts. Never let MicroVM auto-create an empty disk.
        exit 0
      fi
      echo "Initialized Android data image is missing and cannot be recovered" >&2
      exit 1
    fi

    ${pkgs.qemu-utils}/bin/qemu-img create -f raw "$image" 32G
    chown root:redroid-vm-data "$image"
    chmod 0660 "$image"
    ${pkgs.e2fsprogs}/bin/mkfs.ext4 -F -L REDROID_DATA "$image"
    ${pkgs.coreutils}/bin/sync -f "$image"
    write_marker
  '';
in
{
  options.services.redroidLab.idleTimeoutSeconds = lib.mkOption {
    type = lib.types.ints.between 60 86400;
    default = 900;
    description = "Seconds without active ReDroid leases before android-lab is stopped.";
  };

  imports = [ inputs.microvm.nixosModules.host ];

  config = {
    microvm.host.enable = true;
    microvm.autostart = [ ];
    microvm.vms.android-lab = {
      # This points at the independently evaluable flake output, ensuring the
      # host starts the same ARM64 guest exposed as nixosConfigurations.android-lab.
      flake = self;
      autostart = false;
      restartIfChanged = false;
    };

    hardware.ksm.enable = lib.mkForce false;
    security.wrappers.qemu-bridge-helper.enable = lib.mkForce false;
    environment.etc."qemu/bridge.conf".text = lib.mkForce "";

    assertions = [
      {
        assertion = builtins.attrNames config.microvm.vms == [ "android-lab" ];
        message = "chill-penguin must host only the dedicated android-lab MicroVM";
      }
      {
        assertion = config.microvm.autostart == [ ] && !config.microvm.vms.android-lab.autostart;
        message = "android-lab must remain stopped after chill-penguin boots";
      }
      {
        assertion = androidLabConfig.microvm.forwardPorts == [ ];
        message = "android-lab must not forward any guest port to chill-penguin";
      }
      {
        assertion = builtins.any (
          volume:
          volume.image == androidDataImage
          && volume.label == "REDROID_DATA"
          && volume.fsType == "ext4"
          && volume.size == 32768
          && !volume.autoCreate
        ) androidLabConfig.microvm.volumes;
        message = "android-lab must use the guarded persistent 32 GiB REDROID_DATA ext4 image at the controller path";
      }
      {
        assertion =
          androidLabConfig.microvm.hypervisor == "qemu"
          && androidLabConfig.microvm.qemu.machineOpts.accel == "kvm";
        message = "android-lab must use QEMU with explicit KVM acceleration and no TCG fallback";
      }
      {
        assertion = config.virtualisation.oci-containers.containers.redroid-gateway.ports == [ ];
        message = "redroid-gateway must not publish ports on chill-penguin";
      }
    ];

    users.groups.redroid-gateway.gid = 925;
    users.groups.redroid-adb.gid = 926;
    users.groups.redroid-vm-data = { };
    users.users.redroid-adb = {
      uid = 926;
      group = "redroid-adb";
      extraGroups = [ "redroid-gateway" ];
      isSystemUser = true;
      home = "/var/lib/redroid/adb";
      createHome = true;
    };

    environment.systemPackages = [
      pkgs.android-tools
      pkgs.e2fsprogs
      pkgs.qemu-utils
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/redroid 0711 root root -"
      "d /var/lib/redroid/control 0700 root root -"
      "d /var/lib/redroid/adb 0700 redroid-adb redroid-adb -"
      "d /var/lib/redroid/secrets 0750 root redroid-gateway -"
      "d /var/lib/redroid/vsock-auth 0700 root root -"
      "d /run/redroid 0770 root redroid-gateway -"
    ];

    systemd.services.redroid-provision-runtime = {
      description = "Provision private ReDroid gateway credentials and T3 client tools";
      wantedBy = [ "multi-user.target" ];
      after = [
        "local-fs.target"
        "systemd-tmpfiles-setup.service"
      ];
      unitConfig.ConditionPathIsDirectory = t3Home;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = redroidProvision;
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          redroidSecrets
          t3Home
        ];
      };
    };

    systemd.services.redroid-provision-data = {
      description = "Provision or validate the persistent ReDroid data image";
      wantedBy = [ "multi-user.target" ];
      after = [
        "local-fs.target"
        "systemd-tmpfiles-setup.service"
      ];
      requires = [ "systemd-tmpfiles-setup.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = redroidDataProvision;
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ redroidState ];
      };
    };

    systemd.services.redroid-provision-vsock-auth = {
      description = "Create the private host-to-guest ReDroid VSOCK authentication key";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      requires = [ "systemd-tmpfiles-setup.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "redroid-provision-vsock-auth" ''
          set -euo pipefail
          directory=${lib.escapeShellArg redroidVsockAuth}
          install -d -m 0700 -o root -g root "$directory"
          if [ ! -s "$directory/key" ]; then
            umask 077
            ${pkgs.openssl}/bin/openssl rand -hex 32 > "$directory/.key.new"
            install -m 0400 -o root -g root "$directory/.key.new" "$directory/key"
            rm -f "$directory/.key.new"
          fi
          chown root:root "$directory/key"
          chmod 0400 "$directory/key"
          test "$("${pkgs.coreutils}/bin/wc" -c < "$directory/key")" -eq 65
        '';
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ redroidVsockAuth ];
      };
      path = [
        pkgs.coreutils
        pkgs.openssl
      ];
    };

    systemd.services.redroid-control = {
      description = "Narrow root-owned ReDroid MicroVM lifecycle controller";
      wantedBy = [ "multi-user.target" ];
      after = [
        "local-fs.target"
        "systemd-tmpfiles-setup.service"
        "redroid-adb.service"
        "redroid-provision-vsock-auth.service"
        "redroid-provision-data.service"
      ];
      requires = [
        "systemd-tmpfiles-setup.service"
        "redroid-adb.service"
        "redroid-provision-vsock-auth.service"
        "redroid-provision-data.service"
      ];
      environment.REDROID_IDLE_TIMEOUT = "${toString config.services.redroidLab.idleTimeoutSeconds}s";
      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "redroid-gateway";
        UMask = "0007";
        ExecStart = "${redroidLab.redroidControl}/bin/redroid-control";
        Restart = "on-failure";
        RestartSec = "2s";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [
          "/run/redroid"
          redroidState
        ];
        ReadOnlyPaths = [
          redroidSecrets
          redroidVsockAuth
        ];
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_VSOCK"
        ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
      };
    };

    systemd.services.redroid-adb = {
      description = "Private host ADB server for android-lab over AF_VSOCK";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      requires = [ "systemd-tmpfiles-setup.service" ];
      serviceConfig = {
        Type = "simple";
        User = "redroid-adb";
        Group = "redroid-gateway";
        UMask = "0007";
        Environment = "HOME=/var/lib/redroid/adb";
        ExecStart = "${adb} -L localfilesystem:/run/redroid/adb.sock nodaemon server";
        Restart = "on-failure";
        RestartSec = "2s";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [
          "/run/redroid"
          "/var/lib/redroid/adb"
        ];
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_VSOCK"
        ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
      };
    };

    systemd.services."microvm@android-lab" = {
      # Rebuilds must preserve an active T3 session and must never restart the
      # Android guest as a side effect. An explicit systemctl stop stays stopped.
      restartIfChanged = false;
      stopIfChanged = false;
      after = [
        "redroid-provision-vsock-auth.service"
        "redroid-provision-data.service"
      ];
      requires = [
        "redroid-provision-vsock-auth.service"
        "redroid-provision-data.service"
      ];
      serviceConfig = {
        Restart = lib.mkForce "no";
        SupplementaryGroups = [ "redroid-vm-data" ];
        IPAddressDeny = [
          "127.0.0.0/8"
          "10.0.0.0/8"
          "100.64.0.0/10"
          "169.254.0.0/16"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "::/128"
          "::1/128"
          "::ffff:0:0/96"
          "fc00::/7"
          "fe80::/10"
          "ff00::/8"
        ];
      };
    };

    virtualisation.oci-containers.containers.redroid-gateway = {
      image = "localhost/redroid-gateway:latest";
      imageFile = redroidLab.redroidGatewayImage;
      pull = "never";
      user = "925:925";
      ports = [ ];
      extraOptions = [
        "--network=ghostship_net"
        "--cap-drop=ALL"
        "--read-only"
        "--tmpfs=/tmp:rw,noexec,nosuid,nodev,size=2g"
        "--security-opt=no-new-privileges"
        "--pids-limit=128"
      ];
      volumes = [
        "/run/redroid:/run/redroid:ro"
        "${redroidSecrets}/redroid-gateway-token:/run/secrets/redroid-gateway-token:ro"
        "${redroidSecrets}/tls.crt:/run/secrets/tls.crt:ro"
        "${redroidSecrets}/tls.key:/run/secrets/tls.key:ro"
      ];
    };

    systemd.services.podman-redroid-gateway = {
      after = [
        "init-ghostship-net.service"
        "redroid-provision-runtime.service"
        "redroid-control.service"
        "redroid-adb.service"
      ];
      wants = [
        "init-ghostship-net.service"
        "redroid-provision-runtime.service"
        "redroid-control.service"
        "redroid-adb.service"
      ];
      preStart = lib.mkAfter ''
        for attempt in $(seq 1 100); do
          if [ -S /run/redroid/control.sock ] && [ -S /run/redroid/adb.sock ]; then
            exit 0
          fi
          sleep 0.1
        done
        echo "ReDroid controller or host ADB Unix socket did not become ready" >&2
        exit 1
      '';
      restartIfChanged = false;
      stopIfChanged = false;
    };
  };
}
