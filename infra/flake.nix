# flake.nix
{
  description = "My Dinh DC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05"; # pinned channel
    flake-utils.url = "github:numtide/flake-utils";
    disko.url = "github:nix-community/disko";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      disko,
    }:
    {
      nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./disko.nix
          disko.nixosModules.disko

          # main server config
          (
            { config, pkgs, ... }:
            {
              nix.settings.experimental-features = [
                "nix-command"
                "flakes"
              ];
              time.timeZone = "Asia/Bangkok";

              # System state version
              system.stateVersion = "25.05";

              # Hardware configuration
              hardware.enableAllHardware = true;

              # Console-only system (no GUI)
              services.xserver.enable = false;
              services.displayManager.enable = false;
              boot.plymouth.enable = false;

              # Console configuration
              console = {
                enable = true;
                font = "Lat2-Terminus16";
                keyMap = "us";
              };

              # Enable getty on tty1-6
              systemd.services."getty@tty1".enable = true;
              systemd.services."getty@tty2".enable = true;
              systemd.services."getty@tty3".enable = true;
              systemd.services."getty@tty4".enable = true;
              systemd.services."getty@tty5".enable = true;
              systemd.services."getty@tty6".enable = true;

              # UEFI Bootloader
              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = true;

              # Debug options and console configuration
              boot.kernelParams = [
                "console=tty0"
                "console=ttyS0,115200n8"
                "systemd.log_level=info"
                "systemd.log_target=console"
                "boot.shell_on_fail"
              ];

              # Initrd debugging
              boot.initrd.systemd.enable = true;
              boot.initrd.verbose = true;

              # users
              users.users.haitv = {
                isNormalUser = true;
                hashedPassword = "$6$wV.gZ4G6JUE3gikF$OioZi5wbTtZeR31NDgwzqoKC1sAho5qJxttuUE82u/0EBiN9WoBedbMehGPt/kvkzd9lIuHKhgLd0022wBjOJ0";
                extraGroups = [
                  "wheel"
                  "networkmanager"
                  "libvirtd"
                  "docker"
                ];
                openssh.authorizedKeys.keys = [
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB2+OS6UOfiyAeJNyAvFvPLbVhcjeSTHni08+9O0vTjy nixos-vm"
                ];
              };

              # SSH configuration - key-only authentication
              services.openssh = {
                enable = true;
                settings = {
                  PasswordAuthentication = false;
                  PermitRootLogin = "no";
                  KbdInteractiveAuthentication = false;
                  PermitEmptyPasswords = false;
                };
              };

              # Tailscale VPN
              services.tailscale = {
                enable = true;
                useRoutingFeatures = "server";
              };

              # firewall
              networking.firewall = {
                enable = true;
                allowedTCPPorts = [
                  22
                  80
                  443
                ];
                # Allow Tailscale traffic
                trustedInterfaces = [ "tailscale0" ];
                allowedUDPPorts = [ config.services.tailscale.port ];
              };

              # system packages
              environment.systemPackages = with pkgs; [
                git
                vim
                curl
                wget
                tailscale
              ];

              # containers (Podman or Docker)
              virtualisation.docker.enable = true;

              # libvirt/KVM for VMs
              virtualisation.libvirtd.enable = true;
              programs.virt-manager.enable = true;

              # Enable nix-ld for FHS compatibility
              programs.nix-ld.enable = true;

              # housekeeping
              nix.gc = {
                automatic = true;
                dates = "weekly";
                options = "--delete-older-than 14d";
              };

              # backups/snapshots if using btrfs
              services.snapper = {
                snapshotRootOnBoot = true;
                configs.root = {
                  SUBVOLUME = "/";
                  ALLOW_USERS = [ "haitv" ];
                  TIMELINE_CREATE = true;
                  TIMELINE_CLEANUP = true;
                  TIMELINE_MIN_AGE = "1800s";
                  TIMELINE_LIMIT_HOURLY = 8;
                  TIMELINE_LIMIT_DAILY = 7;
                  TIMELINE_LIMIT_WEEKLY = 4;
                  TIMELINE_LIMIT_MONTHLY = 3;
                };
              };
            }
          )
        ];
      };
    };
}
