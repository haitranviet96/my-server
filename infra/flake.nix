# flake.nix
{
  description = "My Dinh DC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"; # pinned channel
    disko.url = "github:nix-community/disko";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
          # Disk configuration
          ./disko.nix
          disko.nixosModules.disko

          # Home Manager integration
          home-manager.nixosModules.home-manager
          ./modules/home-haitv.nix

          # System modules
          ./modules/hardware.nix
          ./modules/storage.nix
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

              substituters = [
                "https://cache.nixos-cuda.org"
              ];

              trusted-public-keys = [
                "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
              ];
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
