{
  disko.devices.disk.main = {
    device = "/dev/vda"; # Will be overridden by disko-install
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          start = "1MiB";
          end = "512MiB";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "defaults" ];
          };
        };
        root = {
          start = "512MiB";
          end = "100%";
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
