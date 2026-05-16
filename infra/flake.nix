# flake.nix
{
  description = "My Dinh DC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # pinned channel
    disko.url = "github:nix-community/disko";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      sops-nix,
      ...
    }:
    {
      nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # Disk configuration
          ./disko.nix
          disko.nixosModules.disko

          # Secrets management
          sops-nix.nixosModules.sops

          # System modules
          ./modules/hardware.nix
          ./modules/ups.nix
          ./modules/storage/flake.nix
          ./modules/networking.nix
          ./modules/users.nix
          ./modules/virtualization.nix
          ./modules/github-runners.nix
          ./modules/programs.nix

          # Base system configuration
          {
            nix.settings = {
              experimental-features = [
                "nix-command"
                "flakes"
              ];
            };

            zramSwap.enable = true;

            boot.kernel.sysctl = {
              "vm.swappiness" = 100;
              "kernel.task_delayacct" = 1; # Enable Task Delay Accounting for iotop
            };

            time.timeZone = "Asia/Bangkok";

            # System state version
            system.stateVersion = "25.11";

            # housekeeping
            nix.gc = {
              automatic = true;
              dates = "weekly";
              options = "--delete-older-than 14d";
            };
          }
        ];
      };
    };
}
