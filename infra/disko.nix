{
  disko.devices.disk.main = {
    device = "/dev/vda"; # Will be overridden by disko-install
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          name = "ESP";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "defaults" "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          name = "root";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "@" = {
                mountpoint = "/";
                mountOptions = [ "subvol=@" "compress=zstd" ];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = [ "subvol=@home" "compress=zstd" ];
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [ "subvol=@nix" "compress=zstd" ];
              };
              "@var" = {
                mountpoint = "/var";
                mountOptions = [ "subvol=@var" "compress=zstd" ];
              };
              "@log" = {
                mountpoint = "/var/log";
                mountOptions = [ "subvol=@log" "compress=zstd" ];
              };
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = [ "subvol=@snapshots" "compress=zstd" ];
              };
            };
          };
        };
      };
    };
  };
}
