# Migration Guide: `chill-penguin` (Mac Studio)

This guide outlines the steps to migrate the `chill-penguin` Mac Studio from a failing Fedora Asahi Remix installation to a fresh, native NixOS configuration using this repository.

> **CRITICAL**: The internal SSD is currently reporting hardware I/O errors and is in Read-Only mode. This process involves a full drive wipe which is the only way to attempt a reset of the NVMe controller lock.

## 1. Prerequisites & Backups
- [x] **Data Secured**: 23.95GB of databases, configs, and metadata have been pulled to the `old/chill-penguin/` directory.
- [ ] **Installer USB**: A 16GB+ USB drive.
- [ ] **Network**: Ethernet connection is highly recommended for the initial install.

## 2. Create the Custom NixOS Installer
Standard NixOS ISOs do not support Apple Silicon boot. You must build a custom one using the `nixos-apple-silicon` flake.

From a machine with Nix installed:
```bash
nix build github:tpwrules/nixos-apple-silicon#installer-iso
# The result will be in ./result/iso/nixos-*.iso
# Flash to USB (replace /dev/sdX with your USB device):
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

## 3. Clear the SSD (Recovery Environment)
Since the drive is locked, a standard `rm` won't work. We need to reset the partition table.

1.  Boot into the **macOS Recovery Environment** (Hold Power button on startup).
2.  Open **Terminal**.
3.  Identify the NixOS/Asahi partitions: `diskutil list`.
4.  Wipe the Linux partitions or the entire non-macOS free space. 
    *   *Note: Since macOS is already wiped in this scenario, use `diskutil eraseDisk` or `gpt destroy` on the internal NVMe to create a completely blank slate.*

## 4. Boot the Installer & Partition
1.  Plug in the custom NixOS USB.
2.  Boot the Mac Studio and select the USB boot option (handled via m1n1/U-Boot).
3.  **Manual Partitioning** (Standard Asahi UEFI layout):
    ```bash
    # Create a new GPT table if not done in step 3
    sgdisk -Z /dev/nvme0n1
    
    # 1. EFI Partition (512MB - 1GB)
    sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"boot" /dev/nvme0n1
    
    # 2. Main NixOS Partition (Remaining space)
    sgdisk -n 2:0:0 -t 2:8300 -c 2:"nixos" /dev/nvme0n1
    ```

4.  **Format and Mount**:
    ```bash
    # Format EFI
    mkfs.vfat -F 32 -n boot /dev/nvme0n1p1
    
    # Format Btrfs
    mkfs.btrfs -L nixos /dev/nvme0n1p2
    mount /dev/nvme0n1p2 /mnt
    
    # Create Subvolumes
    btrfs subvolume create /mnt/root
    btrfs subvolume create /mnt/home
    btrfs subvolume create /mnt/var
    umount /mnt
    
    # Mount for Installation
    mount -o subvol=root,compress=zstd,noatime /dev/nvme0n1p2 /mnt
    mkdir -p /mnt/{boot,home,var}
    mount /dev/nvme0n1p1 /mnt/boot
    mount -o subvol=home,compress=zstd,noatime /dev/nvme0n1p2 /mnt/home
    mount -o subvol=var,compress=zstd,noatime /dev/nvme0n1p2 /mnt/var
    ```

## 5. Bootstrap and Install
1.  **Clone this Repo**:
    ```bash
    mkdir -p /mnt/etc/nixos
    git clone https://github.com/youruser/nixos-config.git /mnt/etc/nixos
    cd /mnt/etc/nixos
    ```

2.  **Run Bootstrap**:
    ```bash
    ./bootstrap.sh chill-penguin
    ```
    *   This will generate a new Age key for SOPS and output a JSON block.
    *   **Action**: Copy that JSON block and save it elsewhere. We will use it to update the repository later.

3.  **Initial Install**:
    ```bash
    nixos-install --flake .#chill-penguin
    ```

4.  **Reboot**:
    ```bash
    umount -R /mnt
    reboot
    ```

## 6. Post-Installation (Data Restore)
Once `chill-penguin` is back online and accessible via SSH:

1.  **Inject Secrets**: Use the Age key from step 5.2 to decrypt and update `secrets.yaml`.
2.  **Restore Data**:
    *   Move the 23GB from `old/chill-penguin/remote_tmp/` to `/srv/apps/config/`.
    *   Extract tarballs: `for f in *.tar; do tar -xf $f -C /srv/apps/config/plex/...; done`
    *   Restore SQLite databases to their respective service folders.
    *   Ensure permissions: `chown -R 1000:1001 /srv/apps/config`.
3.  **Final Build**: Run `nh os switch .` on the host to ensure all Nix-managed configs (Plex Preferences, *Arr XMLs) are correctly merged via `dasel`.
