# flake.nix
{
  description = "My Dinh DC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05"; # pinned channel
    disko.url = "github:nix-community/disko";
  };

  outputs =
    {
      nixpkgs,
      disko,
      ...
    }:
    {
      nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./disko.nix
          disko.nixosModules.disko

          # main server config
          (
            {
              config,
              pkgs,
              lib,
              ...
            }:
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

              # NVIDIA drivers
              services.xserver.videoDrivers = [ "nvidia" ];
              hardware.nvidia = {
                # Modesetting is required for most recent NVIDIA GPUs
                modesetting.enable = true;

                # Enable the Nvidia settings menu accessible via `nvidia-settings`
                nvidiaSettings = false; # Set to false for headless server

                # Enable NVIDIA Power Management (for newer GPUs)
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

              # UEFI Bootloader
              boot.loader.systemd-boot.enable = true;

              # Assemble Intel IMSM (fake RAID) via mdadm at boot. NixOS exposes this via boot.swraid.
              boot.swraid.enable = true;

              # Filesystems
              fileSystems."/media/BackupDisk" = {
                device = "UUID=db7abc45-ab91-4f5f-8fc8-05e283b3952e";
                fsType = "btrfs";
                options = [
                  "noauto"
                  "nofail"
                  "x-systemd.automount"
                  "compress=zstd"
                ];
              };

              fileSystems."/media/Data" = {
                device = "UUID=980b2253-3c7c-4d1a-8cda-98cc74d31670";
                fsType = "btrfs";
                options = [
                  "noauto"
                  "nofail"
                  "x-systemd.automount"
                  "compress=zstd"
                ];
              };

              fileSystems."/media/OLDROOT" = {
                device = "UUID=0cd879fd-1962-4ebb-a5ee-687c8462cb7b";
                fsType = "btrfs";
                options = [
                  "noauto"
                  "nofail"
                  "x-systemd.automount"
                  "compress=zstd"
                  "subvol=@"
                ];
              };

              fileSystems."/media/OLDHOME" = {
                device = "UUID=0cd879fd-1962-4ebb-a5ee-687c8462cb7b";
                fsType = "btrfs";
                options = [
                  "noauto"
                  "nofail"
                  "x-systemd.automount"
                  "compress=zstd"
                  "subvol=@home"
                ];
              };

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
                shell = pkgs.zsh;
              };

              # default shell for all newly created interactive users
              users.defaultUserShell = pkgs.zsh;

              # expose shells
              environment.shells = with pkgs; [
                zsh
                bash
              ];

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
                  61208 # glances HTTP
                  19999 # netdata default port
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
                dua
                tailscale
                nixfmt-rfc-style
                btop-cuda
                gnupg
                sops
                age
                pciutils # for lspci command
                mc
                python3
                bash
              ];

              # containers (Podman or Docker)
              virtualisation.docker.enable = true;

              # Docker networks setup
              systemd.services.docker-networks = {
                description = "Create Docker networks";
                wantedBy = [ "docker.service" ];
                after = [ "docker.service" ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = ''
                    ${pkgs.docker}/bin/docker network create --driver bridge --ipv6 multimedia || true
                    ${pkgs.docker}/bin/docker network create --driver bridge --ipv6 webserver || true
                    ${pkgs.docker}/bin/docker network create --driver bridge --ipv6 tools || true
                  '';
                };
              };

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

              # Zsh configuration
              programs.zsh = {
                enable = true;
                enableCompletion = true;
              };

              # GitHub Actions Runners
              services.github-runners =
                let
                  # Number of runners to create (easily configurable)
                  runnerCount = 3;

                  # Generate runners dynamically
                  generateRunners =
                    count:
                    builtins.listToAttrs (
                      map (
                        i:
                        let
                          runnerName = "runner-${toString i}";
                        in
                        {
                          name = runnerName;
                          value = {
                            enable = true;
                            url = "https://github.com/haitranviet96/my-server";
                            tokenFile = "/var/lib/github-runner/token";
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
                              curl
                              docker
                              docker-compose
                              jq
                              nodejs_20
                              gcc
                              gnumake
                              gnupg
                              sops
                              rsync
                              openssh
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
                        }
                      ) (builtins.genList (i: i + 1) count)
                    );
                in
                generateRunners runnerCount;

              # Ensure github-runner token is persisted
              systemd.tmpfiles.rules = [
                "f /var/lib/github-runner/token 0600 github-runner github-runner - "
              ];

              # Ensure the github-runner user exists and is in docker group
              users.users.github-runner = {
                isSystemUser = true;
                group = "github-runner";
                # Add haitv group for write access to /home/haitv/homepage subdirectories (group-owned)
                extraGroups = [ "docker" "haitv" ];
              };
              users.groups.github-runner = { };

              # housekeeping
              nix.gc = {
                automatic = true;
                dates = "weekly";
                options = "--delete-older-than 14d";
              };

              # backups/snapshots with btrfs
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
