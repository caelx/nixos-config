# Android analysis lab

The `android-lab` MicroVM is a dedicated ARM64 ReDroid environment for APK
installation, debugging, instrumentation, screenshots, logcat, dumpsys, and
filesystem inspection. It runs only on `chill-penguin` and is controlled from
T3 Code through `redroid-gateway` on `ghostship_net`.

## Architecture and boundaries

The Asahi host is ARM64 and may use 16 KiB pages. The guest uses a generic
NixOS ARM64 kernel with 4 KiB pages so BinderFS and ReDroid can run without
changing the host kernel. QEMU uses KVM and outbound-only user networking. The
guest has no forwarded ports, and ReDroid publishes no ports. The gateway has
no host-published ports; its authenticated control and ADB interfaces are
private to `ghostship_net`. The host lifecycle controller accepts only fixed
operations over a root-owned Unix socket. It does not expose a shell or the
Podman socket.

ADB reaches guest adbd over VSOCK through a guest relay and the host ADB server
uses a Unix-domain smart socket. Guest lifecycle requests use a host-generated
HMAC key shared read-only over virtiofs, with per-request expiry and replay
checks. Do not add TCP listeners on the host for
ADB (`5037` or `5555`) or lifecycle control. T3 is the control plane. The
MicroVM is off after host boot and is started on demand. Its Android data
volume persists across container restarts, VM stops, and host reboots.
The host creates the labeled ext4 data image only before writing its durable
initialization marker. Rebuilds validate the existing label, and an initialized
but missing image blocks VM startup unless reset recovery can restore its
quarantined predecessor; it never silently creates blank Android state.

The live chill-penguin preflight on 2026-09-23 reported `aarch64`, a 16,384
byte host page size, `/dev/kvm` present and accessible to root, KVM API version
12, and a successful `KVM_CREATE_VM` probe. The host kernel remains unchanged;
the 4 KiB requirement is handled by the guest kernel.

The guest configuration pins ARM64 Android 14 in rootful Podman and builds
KernelSU-Next into its kernel. Its authenticated ADB shell is configured to
pass KernelSU's shell-root gate; that grants root to the authorized ADB key and
must be treated as privileged access. KernelSU userspace bootstrap, Zygisk
Next, LSPosed, and GApps installation are not yet automated or runtime-verified.
The guest currently provides only hash/provenance verification and staging
helpers for operator-supplied archives. Google account login must be performed
manually after a verified GApps install. Never put Google credentials or
licensed GApps artifacts in Git, Nix expressions, logs, or prompts.

Play Store availability does not imply device certification, Play Integrity,
hardware-backed attestation, Widevine L1, or support for banking and DRM apps
that require physical-device keys. An uncertified device may require Google's
normal GSF Android ID registration process.

## Commands

Use the installed `redroidctl` from T3 Code. Commands that need Android start
the lab when it is off, wait for readiness, and hold an activity lease for the
operation. The idle timeout defaults to 15 minutes; explicit keepalive and
active operations refresh the lease. The ADB server's persistent connection
alone does not count as activity.

On chill-penguin, set `services.redroidLab.idleTimeoutSeconds` to a value from
60 through 86400 in the NixOS host configuration to change the timeout.

```sh
redroidctl status
redroidctl start
redroidctl wait
redroidctl stop
redroidctl restart
redroidctl logs
```

Install and inspect an APK:

```sh
redroidctl install ./app.apk
redroidctl adb shell pm list packages
redroidctl launch com.example.app
redroidctl stop-app com.example.app
```

Root, KernelSU, diagnostics, screenshots, and files:

```sh
redroidctl adb shell id
redroidctl shell 'su -c id'
redroidctl logcat
redroidctl adb shell dumpsys package com.example.app
redroidctl screenshot ./screen.png
redroidctl pull /sdcard/Download/report.db ./report.db
redroidctl push ./payload.bin /sdcard/Download/payload.bin
```

`redroidctl adb` exposes normal Android platform-tools operations, including
package manager and Activity Manager commands, `dumpsys`, bugreports,
forward/reverse, and shell input. Use `redroidctl help` for the exact syntax
provided by the installed version. Screenshots, recordings, and pulled files
are written to the caller-selected path in the T3 workspace.

Factory reset destroys Android user state. It is available only with an
explicit confirmation (`--yes` for deliberate non-interactive use); the
controller requires the VM stopped, no active leases, and a current one-use
reset authorization before replacing the data image. The prior image is
unlinked after the clean image is installed. This is a filesystem-level reset,
not a guarantee that storage media blocks were securely overwritten.

```sh
redroidctl factory-reset
redroidctl factory-reset --yes
```

An explicit stop or restart blocks new analysis leases and waits up to five
minutes for existing operations to finish. If an operation remains active,
the request returns an error and leaves Android running; rerun it after the
operation has ended.

## Health checks

From T3, `redroidctl status` reports controller, MicroVM, guest, ADB, boot,
root, leases, and idle state. The configured KernelSU shell gate is not proof
of a working `su` runtime until deployment. A fully accepted Android instance
must satisfy all of these gates:

```sh
uname -m                         # inside guest: aarch64
getconf PAGESIZE                 # inside guest: 4096
grep binder /proc/filesystems    # inside guest
ls -la /dev/binderfs             # binder, hwbinder, vndbinder
redroidctl adb devices           # device state
redroidctl adb shell getprop sys.boot_completed  # 1
redroidctl adb shell id          # uid=0(root)
redroidctl shell 'su -c id'      # uid=0(root) from KernelSU
redroidctl adb shell pm list packages | grep -E 'google|vending'
```

The package and runtime checks above are acceptance criteria, not a claim that
the un-deployed development configuration already passes them. GApps, Zygisk
Next, and LSPosed remain deployment work until verified installation and
operation have been observed in the guest.

The host controller and VM can be inspected with `systemctl status
redroid-control`, `systemctl status microvm@android-lab`, and the respective
`journalctl -u ...` logs. Gateway logs are available from
`podman-redroid-gateway.service`. No health report should claim Android is
ready based only on the VM process existing.

## Networking and security checks

The guest needs outbound Internet for app and Play Store behavior analysis.
QEMU user networking has no port forwards; the host firewall blocks guest
access to host-private, LAN, link-local, and metadata destinations. The gateway
is reachable from T3 only over `ghostship_net`, using authenticated TLS and a
scoped token. ADB is authenticated. The controller verifies Unix peer
credentials and accepts a fixed RPC vocabulary.

On `chill-penguin`, verify listeners with `ss -lntup`. There must be no LAN
listener for TCP 5037, 5555, or the gateway/control API. Verify the gateway OCI
definition has `ports = [ ]`, and the MicroVM has no `forwardPorts`. From a
separate LAN host, verify those ports are unreachable. ADB uses the VSOCK path
and private Unix socket only.

## Current validation state

Repository evaluation and target-host builds prove configuration structure,
not successful runtime behavior. Do not describe the lab as fully operational
until the authorized deployment has passed the page-size, BinderFS, Android
boot, root, GApps, persistence, idle-stop, T3 control, and LAN-isolation checks
above. The current development workflow preserves the active T3 container;
T3 image changes are deferred until an explicitly authorized restart.
