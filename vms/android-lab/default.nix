{
  config,
  lib,
  pkgs,
  ...
}:

let
  # KernelSU-Next v3.4.0 is the newest tagged release checked for this
  # configuration. Its upstream kernel/setup.sh integration is reproduced
  # below against the pinned source instead of invoking a network-mutating
  # setup script during a build.
  kernelSU = pkgs.fetchFromGitHub {
    owner = "KernelSU-Next";
    repo = "KernelSU-Next";
    rev = "v3.4.0";
    hash = "sha256-FHc49GRLqhILPuuN9i3JF507/skyiJFsnkfsJemGCv0=";
  };

  kernelBase = pkgs.linuxPackages_6_12.kernel.override {
    # QEMU's virt machine supplies ACPI and this guest does not consume DTBs.
    buildDTBs = false;
    # The generic Nix kernel config builder validates symbols before the
    # final derivation's postPatch runs. Mirror the pinned KSU symbols visible
    # on ARM64 so olddefconfig does not prompt after the upstream overlay.
    kernelPatches = [
      {
        name = "kernelsu-kconfig-placeholder";
        patch = pkgs.writeText "kernelsu-kconfig-placeholder.patch" ''
          diff --git a/drivers/Kconfig b/drivers/Kconfig
          --- a/drivers/Kconfig
          +++ b/drivers/Kconfig
          @@ -1,2 +1,3 @@
           # SPDX-License-Identifier: GPL-2.0
          +source "drivers/kernelsu/Kconfig"
           menu "Device Drivers"
          diff --git a/drivers/kernelsu/Kconfig b/drivers/kernelsu/Kconfig
          new file mode 100644
          --- /dev/null
          +++ b/drivers/kernelsu/Kconfig
          @@ -0,0 +1,18 @@
          +menu "KernelSU"
          +config KSU
          +	tristate "KernelSU function support"
          +	depends on KPROBES && EXT4_FS
          +	default y
          +config KSU_DEBUG
          +	bool "KernelSU debug mode"
          +	depends on KSU
          +	default n
          +config KSU_DISABLE_MANAGER
          +	bool "Disable KernelSU manager integration"
          +	depends on KSU
          +	default n
          +config KSU_DISABLE_POLICY
          +	bool "Disable KernelSU policy profiles"
          +	depends on KSU
          +	default n
          +endmenu
        '';
      }
    ];
    structuredExtraConfig = with lib.kernel; {
      ARM64_4K_PAGES = yes;
      ANDROID_BINDER_IPC = yes;
      ANDROID_BINDERFS = yes;
      ANDROID_BINDER_DEVICES = freeform "binder,hwbinder,vndbinder";
      MEMFD_CREATE = yes;
      VSOCKETS = yes;
      VIRTIO_VSOCKETS = module;
      KPROBES = yes;
      KPROBE_EVENTS = yes;
      EXT4_FS = yes;
      SECURITY_SELINUX = yes;
      KSU = yes;
    };
  };

  androidLabKernel = kernelBase.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.python3 ];
    # Linux has no ./configure script. Supplying the setup-hook doc name
    # avoids an upstream multiple-outputs hook nounset edge with newer Bash.
    shareDocName = "linux";

    postPatch =
      (old.postPatch or "")
      + ''
        set -eu
        test -f drivers/Kconfig
        test -f drivers/Makefile
        mkdir -p drivers/kernelsu
        cp -a ${kernelSU}/kernel/. drivers/kernelsu/
        # cp -a preserves the read-only store directory modes from the
        # fetched source; make the vendor subtree writable before adding its
        # sibling UAPI headers and the narrowly patched init source.
        chmod -R u+w drivers/kernelsu
        mkdir -p drivers/kernelsu/uapi
        cp -a ${kernelSU}/uapi/. drivers/kernelsu/uapi/
        mkdir -p drivers/kernelsu/include
        cp -a ${kernelSU}/kernel/include/. drivers/kernelsu/include/
        test -f drivers/kernelsu/uapi/app_profile.h
        test -f drivers/kernelsu/include/klog.h

        # The host controller provisions only its authenticated ADB public key.
        # Permit that authenticated adbd shell identity through KernelSU's su
        # gate so root verification does not depend on first opening the Manager
        # UI. Keep CONFIG_KSU_DEBUG disabled; patch only the v3.4.0 default.
        chmod u+w drivers/kernelsu/core/init.c
        python3 - <<'PY'
        from pathlib import Path

        path = Path("drivers/kernelsu/core/init.c")
        source = path.read_text()
        old = "#else\nbool allow_shell = false;\n#endif"
        new = "#else\nbool allow_shell = true;\n#endif"
        if source.count(old) != 1:
            raise SystemExit("unexpected KernelSU-Next v3.4.0 allow_shell source; refusing patch")
        path.write_text(source.replace(old, new, 1))
        PY

        if ! grep -Fq 'source "drivers/kernelsu/Kconfig"' drivers/Kconfig; then
          sed -i '/^endmenu/i source "drivers/kernelsu/Kconfig"' drivers/Kconfig
        fi
        if ! grep -Fq 'obj-$(CONFIG_KSU) += kernelsu/' drivers/Makefile; then
          printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> drivers/Makefile
        fi
        if ! grep -Fq -- '-I$(objtree)/security/selinux/include' drivers/kernelsu/Kbuild; then
          printf '\nccflags-y += -I$(srctree)/drivers/kernelsu/include -I$(objtree)/security/selinux/include\n' >> drivers/kernelsu/Kbuild
        fi
        grep -Fq 'source "drivers/kernelsu/Kconfig"' drivers/Kconfig
        grep -Fq 'obj-$(CONFIG_KSU) += kernelsu/' drivers/Makefile
        grep -Fq -- '-I$(srctree)/drivers/kernelsu/include' drivers/kernelsu/Kbuild
        grep -Fq -- '-I$(objtree)/security/selinux/include' drivers/kernelsu/Kbuild
        grep -Fq $'#else\nbool allow_shell = true;\n#endif' drivers/kernelsu/core/init.c
      ''
      + (old.postPatch or "");

    # This is an actual build-time assertion over the generated kernel config,
    # not just a declaration in the NixOS module.
    postConfigure =
      (old.postConfigure or "")
      + ''
        set -eu
        test -f "$buildRoot/.config"
        grep -qx 'CONFIG_ARM64_4K_PAGES=y' "$buildRoot/.config"
        grep -qx 'CONFIG_ANDROID_BINDER_IPC=y' "$buildRoot/.config"
        grep -qx 'CONFIG_ANDROID_BINDERFS=y' "$buildRoot/.config"
        grep -qx 'CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"' "$buildRoot/.config"
        grep -qx 'CONFIG_MEMFD_CREATE=y' "$buildRoot/.config"
        grep -qx 'CONFIG_VSOCKETS=y' "$buildRoot/.config"
        grep -qx 'CONFIG_VIRTIO_VSOCKETS=m' "$buildRoot/.config"
        grep -qx 'CONFIG_KSU=y' "$buildRoot/.config"
      ''
      + (old.postConfigure or "");
  });

  androidLabKernelPackages = pkgs.linuxPackagesFor androidLabKernel;

  binderfsCreate = pkgs.writeText "android-lab-create-binderfs-devices.py" ''
    import fcntl
    import os

    # _IOWR('b', 1, struct binderfs_device), Linux UAPI
    # struct binderfs_device { char name[256]; __u32 major; __u32 minor; }
    BINDER_CTL_ADD = (3 << 30) | (264 << 16) | (ord("b") << 8) | 1
    root = "/dev/binderfs"
    ctl = os.open(os.path.join(root, "binder-control"), os.O_RDWR | os.O_CLOEXEC)
    try:
        for name in ("binder", "hwbinder", "vndbinder"):
            path = os.path.join(root, name)
            if os.path.exists(path):
                continue
            request = bytearray(264)
            request[:len(name)] = name.encode()
            fcntl.ioctl(ctl, BINDER_CTL_ADD, request, True)
    finally:
        os.close(ctl)

    for name in ("binder", "hwbinder", "vndbinder"):
        if not os.path.exists(os.path.join(root, name)):
            raise SystemExit("BinderFS device was not created: " + name)
  '';

  guestVsock = pkgs.replaceVars ./guest-vsock.py {
    podman = "${pkgs.podman}";
    coreutils = "${pkgs.coreutils}";
    rootfsPath = rootfsPath;
  };

  gappsProvision = pkgs.writeShellApplication {
    name = "android-lab-verify-gapps-archive";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -eu
      : "''${ANDROID_LAB_GAPPS_ARCHIVE:?Set to an operator-supplied ARM64 Android 14 GApps archive outside the Nix store}"
      : "''${ANDROID_LAB_GAPPS_SOURCE:?Set the provenance URL for the operator-supplied archive}"
      : "''${ANDROID_LAB_GAPPS_SHA256:?Set the independently verified SHA-256 digest}"
      case "$ANDROID_LAB_GAPPS_ARCHIVE" in
        /nix/store/*) echo "GApps archive must not reside in the Nix store" >&2; exit 2 ;;
      esac
      test -f "$ANDROID_LAB_GAPPS_ARCHIVE"
      actual=$(sha256sum "$ANDROID_LAB_GAPPS_ARCHIVE" | cut -d ' ' -f 1)
      test "$actual" = "$ANDROID_LAB_GAPPS_SHA256" || {
        echo "GApps archive SHA-256 verification failed" >&2
        exit 1
      }
      echo "GApps archive hash verified; installation remains an explicit operator action."
    '';
  };

  rootfsPath = "/var/lib/android-lab/redroid-data";
  moduleStaging = "${rootfsPath}/lab-modules";
  moduleStager = pkgs.writeShellApplication {
    name = "android-lab-stage-module";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
    ];
    text = ''
      set -eu
      : "''${ANDROID_LAB_MODULE_ID:?Set to zygisk-next or lsposed}"
      : "''${ANDROID_LAB_MODULE_VERSION:?Set an upstream release version}"
      : "''${ANDROID_LAB_MODULE_ARCHIVE:?Set an operator-supplied ZIP outside the Nix store}"
      : "''${ANDROID_LAB_MODULE_SOURCE:?Set the official release URL}"
      : "''${ANDROID_LAB_MODULE_SHA256:?Set the independently verified SHA-256 digest}"
      case "$ANDROID_LAB_MODULE_ID" in zygisk-next|lsposed) ;; *) echo "unsupported module ID" >&2; exit 2 ;; esac
      case "$ANDROID_LAB_MODULE_VERSION" in *[!A-Za-z0-9._+-]*|"") echo "invalid version" >&2; exit 2 ;; esac
      case "$ANDROID_LAB_MODULE_ARCHIVE" in /nix/store/*) echo "module ZIP must stay outside the Nix store" >&2; exit 2 ;; esac
      case "$ANDROID_LAB_MODULE_SOURCE" in
        https://github.com/LSPosed/ZygiskNext/releases/*|https://github.com/LSPosed/LSPosed/releases/*) ;;
        *) echo "source must be an official release URL" >&2; exit 2 ;;
      esac
      test -f "$ANDROID_LAB_MODULE_ARCHIVE"
      archive_size=$(stat -c %s "$ANDROID_LAB_MODULE_ARCHIVE")
      test "$archive_size" -le 2147483648 || { echo "module archive exceeds 2 GiB limit" >&2; exit 1; }
      actual=$(sha256sum "$ANDROID_LAB_MODULE_ARCHIVE" | cut -d ' ' -f 1)
      test "$actual" = "$ANDROID_LAB_MODULE_SHA256" || { echo "module archive SHA-256 verification failed" >&2; exit 1; }
      python3 - "$ANDROID_LAB_MODULE_ARCHIVE" <<'PY'
      import pathlib
      import sys
      import zipfile
      with zipfile.ZipFile(sys.argv[1]) as archive:
          for name in archive.namelist():
              path = pathlib.PurePosixPath(name)
              if path.is_absolute() or ".." in path.parts:
                  raise SystemExit("unsafe ZIP member path")
          if "module.prop" not in archive.namelist():
              raise SystemExit("ZIP does not contain a KernelSU module.prop")
      PY
      target="${moduleStaging}/$ANDROID_LAB_MODULE_ID/$ANDROID_LAB_MODULE_VERSION"
      install -d -m 0700 "$(dirname "$target")"
      if test -d "$target"; then
        test "$(cat "$target/SHA256")" = "$actual" || { echo "version already staged with different content" >&2; exit 1; }
        echo "$target"
        exit 0
      fi
      temporary="$target.tmp.$$"
      install -d -m 0700 "$temporary"
      install -m 0600 "$ANDROID_LAB_MODULE_ARCHIVE" "$temporary/module.zip"
      printf '%s\n' "$actual" > "$temporary/SHA256"
      printf '%s\n' "$ANDROID_LAB_MODULE_SOURCE" > "$temporary/source"
      mv "$temporary" "$target"
      echo "$target"
      echo "Verified archive staged only; KSU installation and reboot remain an explicit operation." >&2
    '';
  };
in
{
  system.stateVersion = "25.11";

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  microvm.hypervisor = "qemu";
  microvm.vcpu = 6;
  microvm.mem = 10240;
  microvm.qemu.machineOpts = {
    accel = "kvm";
  };
  microvm.interfaces = [
    {
      type = "user";
      id = "qemu";
      mac = "02:00:00:77:00:01";
    }
  ];
  microvm.forwardPorts = [ ];
  microvm.vsock.cid = 77;
  microvm.shares = [
    {
      source = "/var/lib/redroid/vsock-auth";
      mountPoint = "/run/redroid-auth";
      tag = "redroid-control-auth";
      proto = "virtiofs";
      readOnly = true;
    }
  ];

  # The host's guarded provisioning unit creates the first image, then
  # microvm.nix only attaches it. Disabling autoCreate prevents a missing
  # initialized data image from silently becoming blank Android state.
  microvm.volumes = [
    {
      image = "/var/lib/redroid/android-data.ext4";
      mountPoint = rootfsPath;
      size = 32768;
      label = "REDROID_DATA";
      fsType = "ext4";
      autoCreate = false;
    }
  ];

  boot.kernelPackages = androidLabKernelPackages;
  boot.kernelModules = [ "vmw_vsock_virtio_transport" ];
  boot.extraModulePackages = [ ];
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
  ];

  assertions = [
    {
      assertion = config.nixpkgs.hostPlatform.system == "aarch64-linux";
      message = "android-lab must be an ARM64 guest";
    }
    {
      assertion = config.boot.kernelPackages.kernel.modDirVersion != "";
      message = "android-lab custom 4 KiB Binder/KernelSU kernel must be selected";
    }
    {
      assertion = config.microvm.vsock.cid == 77;
      message = "android-lab VSOCK CID is fixed at 77";
    }
    {
      assertion = config.microvm.forwardPorts == [ ];
      message = "android-lab must not forward ports through QEMU user networking";
    }
    {
      assertion =
        config.microvm.volumes == [
          {
            image = "/var/lib/redroid/android-data.ext4";
            mountPoint = rootfsPath;
            size = 32768;
            label = "REDROID_DATA";
            fsType = "ext4";
            autoCreate = false;
            serial = null;
            direct = false;
            readOnly = false;
            mkfsExtraArgs = [ ];
            imageType = "raw";
          }
        ];
      message = "android-lab requires its dedicated labeled 32 GiB ext4 /data volume";
    }
    {
      assertion =
        lib.hasInfix "@sha256:" config.virtualisation.oci-containers.containers.redroid.image
        && !(lib.hasInfix ":latest" config.virtualisation.oci-containers.containers.redroid.image);
      message = "ReDroid image must use a pinned immutable digest, not a mutable tag";
    }
    {
      assertion = config.virtualisation.oci-containers.containers.redroid.ports == [ ];
      message = "ReDroid must not publish ports from the isolated guest";
    }
  ];

  # Upstream Linux 6.12 has no CONFIG_ANDROID Kconfig symbol. It does provide
  # built-in Binder IPC/BinderFS, memfd, and 4 KiB page support; do not invent
  # a placeholder CONFIG_ANDROID symbol.
  # The host MicroVM declaration must attach a 32 GiB ext4 block volume with
  # this label (the host VM-volume file is provisioned under /var/lib/redroid).
  # Missing/incorrect storage intentionally fails the ReDroid unit's mount
  # dependency rather than falling back to ephemeral VM root storage.
  fileSystems.${rootfsPath} = {
    device = "/dev/disk/by-label/REDROID_DATA";
    fsType = "ext4";
    options = [ "noatime" ];
    neededForBoot = true;
  };

  fileSystems."/dev/binderfs" = {
    device = "binder";
    fsType = "binder";
    options = [ "stats=global" ];
  };

  fileSystems."/run/redroid-auth" = {
    device = "redroid-control-auth";
    fsType = "virtiofs";
    options = [ "ro" ];
    neededForBoot = true;
  };

  networking.nameservers = [ "9.9.9.9" ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers.redroid = {
    # The OCI digest below is the arm64 child manifest of the official
    # Android 14 64-only image index; it cannot float when upstream retags.
    image = "docker.io/redroid/redroid@sha256:46478a567194aed24cd0877d4434a9e58b534d4aad30931eb21999a52f2ce131";
    pull = "missing";
    autoStart = true;
    privileged = true;
    ports = [ ];
    volumes = [ "${rootfsPath}:/data:rw" ];
    devices = [
      "/dev/binderfs/binder:/dev/binder"
      "/dev/binderfs/hwbinder:/dev/hwbinder"
      "/dev/binderfs/vndbinder:/dev/vndbinder"
    ];
    extraOptions = [
      "--network=android-lab"
      "--ip=10.99.77.2"
      "--security-opt=seccomp=unconfined"
      "--security-opt=apparmor=unconfined"
    ];
    cmd = [
      "androidboot.redroid_width=1080"
      "androidboot.redroid_height=1920"
      "androidboot.redroid_dpi=420"
      "androidboot.redroid_gpu_mode=guest"
      "androidboot.use_memfd=1"
      "ro.secure=0"
      "ro.debuggable=1"
      "ro.adb.secure=1"
      "persist.adb.tcp.port=5555"
    ];
  };

  systemd.services.android-lab-binderfs-devices = {
    description = "Create the ReDroid BinderFS device nodes";
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-redroid.service" ];
    after = [
      "local-fs.target"
      "systemd-modules-load.service"
    ];
    requires = [ "dev-binderfs.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.python3}/bin/python3 ${binderfsCreate}";
    };
  };

  systemd.services.android-lab-redroid-network = {
    description = "Create the private ReDroid container network";
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-redroid.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "android-lab-create-podman-network" ''
        set -eu
        if ! ${pkgs.podman}/bin/podman network exists android-lab; then
          ${pkgs.podman}/bin/podman network create \
            --subnet 10.99.77.0/24 \
            --gateway 10.99.77.1 \
            android-lab
        fi
      '';
    };
  };

  systemd.services.podman-redroid = {
    requires = [
      "android-lab-binderfs-devices.service"
      "android-lab-redroid-network.service"
      "var-lib-android\\x2dlab-redroid\\x2ddata.mount"
    ];
    after = [
      "android-lab-binderfs-devices.service"
      "android-lab-redroid-network.service"
      "var-lib-android\\x2dlab-redroid\\x2ddata.mount"
    ];
  };

  systemd.services.android-lab-vsock = {
    description = "Android Lab guest control and private ADB VSOCK relays";
    wantedBy = [ "multi-user.target" ];
    after = [ "podman-redroid.service" ];
    requires = [ "podman-redroid.service" ];
    restartIfChanged = false;
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 ${guestVsock}";
      Restart = "on-failure";
      RestartSec = "2s";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [
        "/run/podman"
        "/run/containers"
        "/var/lib/containers"
        rootfsPath
      ];
    };
    path = [ pkgs.podman ];
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    extraCommands = ''
      ${pkgs.iptables}/bin/iptables -C INPUT -p tcp --dport 5555 -j DROP 2>/dev/null || \
        ${pkgs.iptables}/bin/iptables -I INPUT 1 -p tcp --dport 5555 -j DROP
      ${pkgs.iptables}/bin/iptables -C FORWARD -d 10.99.77.2/32 -p tcp --dport 5555 -j DROP 2>/dev/null || \
        ${pkgs.iptables}/bin/iptables -I FORWARD 1 -d 10.99.77.2/32 -p tcp --dport 5555 -j DROP
    '';
  };

  environment.systemPackages = [
    pkgs.android-tools
    pkgs.e2fsprogs
    gappsProvision
    moduleStager
  ];

  # Operator-supplied GApps are intentionally not part of this guest's system
  # closure. A release, source, and hash must be verified before installation.
  environment.etc."android-lab/redroid-image".text =
    "docker.io/redroid/redroid@sha256:46478a567194aed24cd0877d4434a9e58b534d4aad30931eb21999a52f2ce131\n";

  # Include the expected kernel symbols in the VM closure so configuration
  # evaluation exposes a stable, inspectable acceptance artifact.
  system.build.androidLabKernelRequirements = pkgs.writeText "android-lab-kernel-requirements" ''
    CONFIG_ARM64_4K_PAGES=y
    # Linux 6.12 does not define CONFIG_ANDROID; Binder support is built-in.
    CONFIG_ANDROID_BINDER_IPC=y
    CONFIG_ANDROID_BINDERFS=y
    CONFIG_MEMFD_CREATE=y
    CONFIG_VSOCKETS=y
    CONFIG_VIRTIO_VSOCKETS=m
    CONFIG_KSU=y
  '';
}
