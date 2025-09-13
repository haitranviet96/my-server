#!/usr/bin/env bash
set -euo pipefail

# === Variables ===
DISK="/dev/vda"                # change this (e.g. /dev/sda or /dev/nvme0n1)
HOSTNAME="nixos"
USERNAME="haitv"

# === Cleanup previous installation attempts ===
sudo umount -R /mnt/disko-install-root 2>/dev/null || true
sudo rm -rf /mnt/disko-install-root 2>/dev/null || true

# === Install NixOS with disko-install ===
sudo nix --extra-experimental-features "nix-command flakes" run 'github:nix-community/disko/latest#disko-install' -- --flake .#myserver --disk main "$DISK"

# === Set root password after first boot ===
echo ">>> Installation complete. Reboot, then run 'passwd' to set root password."
