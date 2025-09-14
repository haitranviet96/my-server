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

              # UEFI Bootloader
              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = true;
              
              # Debug options
              boot.kernelParams = [
                "systemd.log_level=debug"
                "systemd.log_target=console"
                "console=tty0"
                "boot.shell_on_fail"
              ];
              
              # Initrd debugging
              boot.initrd.systemd.enable = true;
              boot.initrd.verbose = true;

              # users
              users.users.haitv = {
                isNormalUser = true;
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

              services.openssh.enable = true;

              # firewall
              networking.firewall = {
                enable = true;
                allowedTCPPorts = [
                  22
                  80
                  443
                ];
              };

              # system packages
              environment.systemPackages = with pkgs; [
                git
                vim
                curl
                wget
              ];

              # containers (Podman or Docker)
              virtualisation.docker.enable = true;

              # libvirt/KVM for VMs
              virtualisation.libvirtd.enable = true;
              programs.virt-manager.enable = true;

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
