#!/usr/bin/env bash
set -euo pipefail

# === Variables ===
DISK="/dev/vda"                # change this (e.g. /dev/sda or /dev/nvme0n1)
HOSTNAME="nixos"
USERNAME="haitv"

# === Partition and format with disko ===
sudo nix --extra-experimental-features "nix-command flakes" run 'github:nix-community/disko/latest' -- --mode destroy,format,mount ./disko.nix --arg device '"'$DISK'"'

# === Generate hardware configuration ===
sudo nixos-generate-config --root /mnt

# === Install NixOS ===
sudo nixos-install --flake .#myserver --root /mnt --no-root-passwd

# === Set root password after first boot ===
echo ">>> Installation complete. Reboot, then run 'passwd' to set root password."
