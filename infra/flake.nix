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
            { config, pkgs, lib, ... }:
            {
              nix.settings.experimental-features = [
                "nix-command"
                "flakes"
              ];
              time.timeZone = "Asia/Bangkok";

              # Allow unfree packages (needed for NVIDIA drivers)
              nixpkgs.config.allowUnfree = true;

              # System state version
              system.stateVersion = "25.05";

              # Hardware configuration
              hardware.enableAllHardware = true;

              # NVIDIA drivers
              services.xserver.videoDrivers = [ "nvidia" ];
              hardware.nvidia = {
                # Modesetting is required for most recent NVIDIA GPUs
                modesetting.enable = true;

                # Enable the Nvidia settings menu accessible via `nvidia-settings`
                nvidiaSettings = false; # Set to false for headless server

                # Optionally, you may need to select the appropriate driver version for your GPU
                # package = config.boot.kernelPackages.nvidiaPackages.stable;

                # Enable NVIDIA Power Management (for newer GPUs)
                powerManagement.enable = true;
                powerManagement.finegrained = false;

                # Use open source kernel module (recommended for RTX/GTX 16xx and newer)
                # Set to false if you have older GPUs or encounter issues
                open = true;
              };

              # Enable CUDA support
              hardware.nvidia-container-toolkit.enable = true;
              hardware.graphics = {
                enable = true;
                enable32Bit = true;
              };

              # Console-only system (no GUI)
              services.xserver.enable = false;
              boot.plymouth.enable = false;

              # UEFI Bootloader
              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = true;

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
                  20443 # speedtest-tracker HTTPS
                  23001 # uptime-kuma HTTPS
                ];
                # Allow Tailscale traffic
                trustedInterfaces = [ "tailscale0" ];
                allowedUDPPorts = [ config.services.tailscale.port ];
              };

              # system packages
              environment.systemPackages = with pkgs; [
                inetutils
                vim
                curl
                wget
                tailscale
                nixfmt-rfc-style
                btop-cuda
                gnupg
                sops
                age
                pciutils # for lspci command
              ];

              # containers (Podman or Docker)
              virtualisation.docker.enable = true;
              virtualisation.oci-containers.backend = "docker";

              # Enable virtualization stack
              virtualisation.libvirtd = {
                enable = true;
                qemu = {
                  package = pkgs.qemu_kvm;
                  runAsRoot = true;
                  swtpm.enable = true;
                  ovmf = {
                    enable = true;
                    packages = [
                      (pkgs.OVMF.override {
                        secureBoot = true;
                        tpmSupport = true;
                      }).fd
                    ];
                  };
                };
              };

              # Enable nix-ld for FHS compatibility
              programs.nix-ld.enable = true;

              # GPG configuration
              programs.gnupg.agent = {
                enable = true;
                pinentryPackage = pkgs.pinentry-curses; # For headless server
              };

              # Git configuration
              programs.git = {
                enable = true;
                config = {
                  user = {
                    name = "Hai Tran";
                    email = "haitranviet96@gmail.com";
                  };
                  credential.helper = "store";
                };
              };

              # GitHub Actions Runners
              services.github-runners = let
                # Number of runners to create (easily configurable)
                runnerCount = 3;
                
                # Generate runners dynamically
                generateRunners = count: builtins.listToAttrs (
                  map (i: let
                    runnerName = "runner-${toString i}";
                  in {
                    name = runnerName;
                    value = {
                      enable = true;
                      url = "https://github.com/haitranviet96/my-server";
                      tokenFile = "/run/secrets/gh_pat";
                      ephemeral = true;
                      replace = true;
                      name = "nixos-${runnerName}";
                      
                      extraLabels = [ 
                        "nixos" 
                        "docker" 
                        "self-hosted" 
                        "ephemeral" 
                        "instance-${toString i}"
                        "cuda"
                      ];
                      
                      extraPackages = with pkgs; [
                        docker docker-compose git curl wget jq
                        nodejs_20 python3 gcc gnumake
                      ];
                      
                      serviceOverrides = {
                        SupplementaryGroups = [ "docker" ];
                        Restart = pkgs.lib.mkForce "always";
                        RestartSec = "10s";
                        
                        # Cleanup before each job
                        ExecStartPre = [
                          "${pkgs.docker}/bin/docker system prune -f --volumes"
                        ];
                        
                        # Resource limits
                        MemoryMax = "6G";
                        CPUQuota = "300%";
                        
                        # Security
                        NoNewPrivileges = true;
                        PrivateTmp = true;
                      };
                    };
                  }) (builtins.genList (i: i + 1) count)
                );
              in generateRunners runnerCount;

              # Ensure the github-runner user exists and is in docker group
              users.users.github-runner = {
                isSystemUser = true;
                group = "github-runner";
                extraGroups = [ "docker" ];
              };
              users.groups.github-runner = {};

              # housekeeping
              nix.gc = {
                automatic = true;
                dates = "weekly";
                options = "--delete-older-than 14d";
              };

              # backups/snapshots if using btrfs
              services.snapper = {
                configs = {
                  root = {
                    SUBVOLUME = "/";
                    ALLOW_USERS = [ "haitv" ];
                    TIMELINE_CREATE = true;
                    TIMELINE_CLEANUP = true;
                    TIMELINE_MIN_AGE = "86400s"; # 24 hours
                    TIMELINE_LIMIT_DAILY = 7;
                    TIMELINE_LIMIT_WEEKLY = 1;
                  };
                  home = {
                    SUBVOLUME = "/home";
                    ALLOW_USERS = [ "haitv" ];
                    TIMELINE_CREATE = true;
                    TIMELINE_CLEANUP = true;
                    TIMELINE_MIN_AGE = "86400s"; # 24 hours
                    TIMELINE_LIMIT_DAILY = 7;
                    TIMELINE_LIMIT_WEEKLY = 3;
                    TIMELINE_LIMIT_MONTHLY = 1;
                  };
                };
              };
            }
          )
        ];
      };
    };
}
