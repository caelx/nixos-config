# Migration Guide: `chill-penguin` (Mac Studio)

This guide provides the complete, step-by-step process for migrating your Mac Studio from its failing Asahi Linux installation to a fresh NixOS setup using this repository. It follows the official "UEFI Standalone" installation method.

---

## 1. Prerequisites & Backups
- [x] **Data Secured**: 23.95GB of databases, configs, and metadata pulled to `old/chill-penguin/`.
- [ ] **USB Drive**: Minimum 512MB (16GB+ recommended).
- [ ] **Internet**: Wi-Fi or Ethernet.

---

## 2. Software Preparation (Build Installer)
Standard NixOS ISOs won't boot on Apple Silicon. You must build a custom bootstrap image.

### Build via NixOS in WSL2:
1.  **Build the ISO** (using binary cache to avoid a massive cross-compile):
    ```bash
    nix build github:tpwrules/nixos-apple-silicon#packages.x86_64-linux.installer-bootstrap \
      --extra-substituters https://nixos-apple-silicon.cachix.org \
      --extra-trusted-public-keys "nixos-apple-silicon.cachix.org-1:99u9ab+GY9ST64WcjF0QMnqKSCDasA/6bGuD6uQB9vY="
    ```
    *Note: If this still crashes, you can download a pre-built ISO from the [Releases page](https://github.com/nix-community/nixos-apple-silicon/releases).*
2.  **Copy to Windows**:
    ```bash
    cp $(readlink -f result/iso/nixos-*.iso) /mnt/c/Users/$USER/Downloads/nixos-apple-silicon.iso
    ```
3.  **Flash with Rufus**:
    *   **Device**: Your USB drive.
    *   **Boot selection**: Select the `.iso` file.
    *   **Partition scheme**: GPT.
    *   **Target system**: UEFI (non CSM).
    *   **START** to flash.

---

## 3. UEFI Preparation (The Asahi Script)
Even for a reinstall, you must run the Asahi script from macOS to ensure the boot environment and peripheral firmware are correctly staged.

1.  Boot into **macOS** (if possible) or **macOS Recovery** (Hold Power button).
2.  Open Terminal and run:
    ```bash
    curl https://alx.sh | sh
    ```
3.  **Follow the Prompts**:
    *   **Resize**: Allocate the entire free space (or desired amount) for NixOS.
    *   **Install OS**: Select **"UEFI environment only"**.
    *   **Name**: Set the OS name to "NixOS".
4.  **Security Mode**: After the script finishes, shut down. Hold the Power button to enter the startup picker, select "NixOS", and follow the prompts to enter **Permissive Security** mode. This is required for m1n1 to boot custom kernels.

---

## 4. Boot the Installer & Connect
1.  Plug in your custom USB.
2.  Power on and select the USB drive in the U-Boot menu (if it doesn't auto-boot, use the `bootmenu` command).
3.  **Connect to Wi-Fi**:
    ```bash
    iwctl
    # Inside iwctl prompt:
    device list
    station wlan0 scan
    station wlan0 get-networks
    station wlan0 connect "YOUR_SSID"
    # Enter password and 'exit'
    ```
4.  **Verify**: `ping google.com`

---

## 5. Partitioning & Formatting (Manual)
> **WARNING**: Do NOT use automated partitioners. Do not touch partitions like `iBootSystemContainer` or `RecoveryOSContainer`.

1.  **Identify Partitions**: `lsblk` or `sgdisk -p /dev/nvme0n1`.
2.  **Create Root Partition**:
    Find the free space created by the Asahi script. 
    ```bash
    # Create partition (Type 8300 - Linux Filesystem)
    sgdisk -n 0:0:0 -t 0:8300 -c 0:"nixos" /dev/nvme0n1
    ```
3.  **Format Btrfs**:
    ```bash
    mkfs.btrfs -L nixos /dev/nvme0n1pX  # Replace pX with your new partition number
    ```
4.  **Create Subvolumes**:
    ```bash
    mount /dev/disk/by-label/nixos /mnt
    btrfs subvolume create /mnt/root
    btrfs subvolume create /mnt/home
    btrfs subvolume create /mnt/var
    umount /mnt
    ```

---

## 6. Mount & Install
1.  **Mount Hierarchy**:
    ```bash
    # Mount Root
    mount -o subvol=root,compress=zstd,noatime /dev/disk/by-label/nixos /mnt
    
    # Mount Subvolumes
    mkdir -p /mnt/{boot,home,var}
    mount -o subvol=home,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/home
    mount -o subvol=var,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/var
    
    # Mount EFI (Crucial: Use the partition UUID from the device tree)
    mount /dev/disk/by-partuuid/$(cat /proc/device-tree/chosen/asahi,efi-system-partition) /mnt/boot
    ```

2.  **Clone Repo**:
    ```bash
    mkdir -p /mnt/etc/nixos
    git clone https://github.com/caelx/nixos-config.git /mnt/etc/nixos
    cd /mnt/etc/nixos
    ```

3.  **Bootstrap**:
    ```bash
    ./bootstrap.sh chill-penguin
    ```
    *   **Action**: Note the Age public key and hardware config output.

4.  **Perform Installation**:
    ```bash
    nixos-install --flake .#chill-penguin
    ```

5.  **Finish**:
    ```bash
    umount -R /mnt
    reboot
    ```

---

## 7. Post-Migration (Restore)
Once booted into the new system:
1.  **Copy Data**: Transfer the 23GB backup to `/srv/apps/config`.
2.  **Restore DBs**: Replace service `.db` files with the backed-up versions.
3.  **Unpack Metadata**: 
    ```bash
    tar -xf plex_metadata.tar -C "/var/lib/plex/Library/Application Support/Plex Media Server"
    ```
4.  **Switch Config**: Run `nh os switch .` to finalize the system state.
