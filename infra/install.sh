#!/usr/bin/env bash
set -euo pipefail

# === Variables ===
DISK="/dev/vda"                # change this (e.g. /dev/sda or /dev/nvme0n1)
HOSTNAME="nixos"
USERNAME="haitv"
FLAKE="github:haitranviet96/yourflake#nixos"  # your flake URI (local path or GitHub)

# === Partition disk ===
parted --align optimal --script "$DISK" \
  mklabel gpt \
  mkpart ESP fat32 1MiB 512MiB \
  set 1 esp on \
  mkpart primary 512MiB 100%

# === Format ===
mkfs.fat -F32 "${DISK}p1"
mkfs.btrfs -f "${DISK}p2"

# === Btrfs subvolumes ===
mount "${DISK}p2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots
umount /mnt

# === Mount subvolumes ===
mount -o subvol=@,compress=zstd "${DISK}p2" /mnt
mkdir -p /mnt/{boot,home,nix,var,log,.snapshots}
mount -o subvol=@home,compress=zstd "${DISK}p2" /mnt/home
mount -o subvol=@nix,compress=zstd  "${DISK}p2" /mnt/nix
mount -o subvol=@var,compress=zstd  "${DISK}p2" /mnt/var
mount -o subvol=@log,compress=zstd  "${DISK}p2" /mnt/log
mount -o subvol=@snapshots,compress=zstd  "${DISK}p2" /mnt/.snapshots
mount "${DISK}p1" /mnt/boot

# === NixOS Install via Flake ===
# nixos-install --flake "$FLAKE" --root /mnt --no-root-passwd
nixos-generate-config --root /mnt

# === Set root password after first boot ===
echo ">>> Installation complete. Reboot, then run 'passwd' to set root password."
