# Storage configuration: filesystems, btrbk backups, gdrive-backup
{ config, pkgs, lib, ... }:
{
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

  # Google Drive backup timer (daily at 3am)
  systemd.timers.gdrive-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
    };
  };
}
