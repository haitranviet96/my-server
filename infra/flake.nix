# flake.nix
{
  description = "My Dinh DC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";   # pinned channel
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, flake-utils, sops-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        packages.default = pkgs.hello;  # optional placeholder
      }
    ) // {
      nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/mydinh-dc/hardware-configuration.nix

          # main server config
          ({ config, pkgs, ... }: {
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            time.timeZone = "Asia/Bangkok";

            # auto upgrades with rollback safety (always pinned by flake.lock)
            system.autoUpgrade = {
              enable = true;
              flake = "github:YOUR_GH_USER/infra#myserver";
              dates = "03:30";
              randomizedDelaySec = "30min";
            };

            # users
            users.users.hai = {
              isNormalUser = true;
              extraGroups = [ "wheel" "networkmanager" "libvirtd" "docker" ];
              openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA... your-key" ];
            };

            services.openssh.enable = true;

            # firewall
            networking.firewall = {
              enable = true;
              allowedTCPPorts = [ 22 80 443 ];
            };

            # containers (Podman or Docker)
            virtualisation.docker.enable = true;
            # or:
            # virtualisation.oci-containers = {
            #   backend = "podman";
            #   containers.myapp = {
            #     image = "ghcr.io/owner/app:stable";
            #     ports = [ "8080:80" ];
            #     environment = { NODE_ENV = "production"; };
            #     volumes = [ "/srv/myapp:/data" ];
            #     autoStart = true;
            #   };
            # };

            # libvirt/KVM for VMs
            virtualisation.libvirtd.enable = true;
            programs.virt-manager.enable = true;

            # k3s optional (if you want k8s)
            # services.k3s = {
            #   enable = true;
            #   role = "server";
            #   extraServerArgs = [ "--disable=traefik" ];
            # };

            # sops-nix for secrets
            imports = [ sops-nix.nixosModules.sops ];
            sops = {
              defaultSopsFile = ./secrets/secrets.yaml;
              age.keyFile = "/var/lib/sops-nix/key.txt";  # provision this once
            };

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
                ALLOW_USERS = [ "hai" ];
                TIMELINE_CREATE = true;
                TIMELINE_CLEANUP = true;
                TIMELINE_MIN_AGE = "1800s";
                TIMELINE_LIMIT_HOURLY = 8;
                TIMELINE_LIMIT_DAILY = 7;
                TIMELINE_LIMIT_WEEKLY = 4;
                TIMELINE_LIMIT_MONTHLY = 3;
              };
            };
          })
        ];
      };
    };
}
