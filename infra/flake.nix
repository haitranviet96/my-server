# flake.nix
{
  description = "My Dinh DC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05"; # pinned channel
    disko.url = "github:nix-community/disko";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      home-manager,
      ...
    }:
    {
      nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./disko.nix
          disko.nixosModules.disko

          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.haitv =
              {
                pkgs,
                config,
                ...
              }:
              {
                # Enable home-manager
                programs.home-manager.enable = true;

                # Home Manager state version
                home.stateVersion = "25.05";

                # Install Node.js and pnpm
                home.packages = with pkgs; [
                  nodejs
                  pnpm
                ];

                # Add Codex binary path to user session
                home.sessionPath = [ "$HOME/.local/bin" ];

                # Configure pnpm global directory
                home.sessionVariables = {
                  PNPM_HOME = "$HOME/.local/share/pnpm";
                };

                # Auto-install OpenAI Codex CLI via pnpm
                home.activation.installCodex = config.lib.dag.entryAfter [ "writeBoundary" ] ''
                  if ! [ -f "$HOME/.local/bin/codex" ]; then
                    echo "Installing Codex CLI via pnpm..."
                    
                    # Ensure directories exist
                    mkdir -p "$HOME/.local/bin"
                    mkdir -p "$HOME/.local/share/pnpm"
                    
                    # Set up pnpm config for global installations
                    export PNPM_HOME="$HOME/.local/share/pnpm"
                    export PATH="$HOME/.local/bin:${pkgs.nodejs}/bin:${pkgs.pnpm}/bin:$PNPM_HOME:$PATH"
                    
                    # Configure pnpm global bin directory
                    ${pkgs.pnpm}/bin/pnpm config set global-bin-dir "$HOME/.local/bin"
                    ${pkgs.pnpm}/bin/pnpm config set global-dir "$HOME/.local/share/pnpm"
                    
                    # Install Codex CLI globally
                    ${pkgs.pnpm}/bin/pnpm add -g @openai/codex || echo "Failed to install Codex CLI"
                  fi
                '';
              };
          }

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

              # Enable kernel config for iotop
              boot.kernelParams = [ "delayacct" ];

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
                btrbk
                tmux
                rclone
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

              # Docker autostart - start all containers at boot
              systemd.services.docker-autostart = {
                description = "Start all Docker containers at boot";
                wantedBy = [ "multi-user.target" ];
                after = [ "docker.service" ];
                requires = [ "docker.service" ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker start $(${pkgs.docker}/bin/docker ps -aq) || true'";
                };
              };

              # Docker autostop - stop all containers on shutdown/reboot
              systemd.services.docker-autostop = {
                description = "Stop all Docker containers on shutdown or reboot";
                wantedBy = [
                  "halt.target"
                  "reboot.target"
                  "shutdown.target"
                ];
                before = [
                  "shutdown.target"
                  "reboot.target"
                  "halt.target"
                ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = "${pkgs.coreutils}/bin/true";
                  ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker stop $(${pkgs.docker}/bin/docker ps -q) || true'";
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

              # iotop with kernel support
              programs.iotop.enable = true;

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
                              # Essential system tools for NixOS workflows
                              gawk
                              coreutils
                              util-linux
                              sudo
                              nixos-rebuild
                              git
                              nix
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

                              # Security - Relaxed for NixOS rebuilds that need sudo
                              # Must force override these to allow sudo to work
                              NoNewPrivileges = pkgs.lib.mkForce false;
                              PrivateUsers = pkgs.lib.mkForce false;
                              RestrictSUIDSGID = pkgs.lib.mkForce false;
                              DynamicUser = pkgs.lib.mkForce false;
                              
                              # Keep some security features
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
                extraGroups = [ "docker" ];
              };
              users.groups.github-runner = { };

              # Allow github-runner to use sudo for NixOS operations
              security.sudo.extraRules = [
                {
                  users = [ "github-runner" ];
                  commands = [
                    {
                      command = "ALL";
                      options = [ "NOPASSWD" ];
                    }
                  ];
                }
              ];

              # housekeeping
              nix.gc = {
                automatic = true;
                dates = "weekly";
                options = "--delete-older-than 14d";
              };

              # btrbk incremental backups
              environment.etc."btrbk/btrbk.conf".text = ''
                snapshot_preserve_min latest
                snapshot_preserve 7d
                stream_compress zstd

                # Root filesystem: local snapshots only
                volume /
                  snapshot_dir .snapshots
                  snapshot_create always
                  subvolume /
                    snapshot_name root

                # Home filesystem: local snapshots + external backup
                volume /home
                  snapshot_dir .snapshots
                  snapshot_create always
                  target /media/BackupDisk/@home
                    target_preserve 7d 3w 1m
                  subvolume /home
                    snapshot_name home

                # Data volume: local snapshots + external backup
                volume /media/Data
                  snapshot_dir .snapshots
                  snapshot_create always
                  target /media/BackupDisk/@data
                    target_preserve 7d 3w 3m
                  subvolume /media/Data/@archived
                    snapshot_name archived
                  subvolume /media/Data/@mydata
                    snapshot_name mydata
              '';

              # btrbk systemd service (runs once)
              systemd.services.btrbk = {
                description = "Incremental btrfs backups";
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = "${pkgs.btrbk}/bin/btrbk run";
                };
                # Ensure BackupDisk is mounted before running
                after = [ "media-BackupDisk.mount" ];
                wants = [ "media-BackupDisk.mount" ];
              };

              # btrbk systemd timer (daily at 2am)
              systemd.timers.btrbk = {
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = "*-*-* 02:00:00";
                  Persistent = true;
                };
              };

              # Google Drive backup service (runs once per week)
              # Syncs current data directly to Google Drive
              systemd.services.gdrive-backup = {
                description = "Sync latest backups to Google Drive";
                serviceConfig = {
                  Type = "oneshot";
                  User = "root";
                  ExecStart = "/home/haitv/my-server/scripts/backup/gdrive-sync.sh";
                };
                # Run after Data is mounted
                after = [ "media-Data.mount" ];
                wants = [ "media-Data.mount" ];
              };

              # Google Drive backup timer (weekly on Sunday at 3am)
              systemd.timers.gdrive-backup = {
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = "Sun *-*-* 03:00:00";
                  Persistent = true;
                };
              };
            }
          )
        ];
      };
    };
}
