# Storage configuration: filesystems, btrbk backups, gdrive-backup
{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Filesystems
  fileSystems."/media/BackupData" = {
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

  fileSystems."/media/BackupSystem" = {
    device = "UUID=d840202e-d646-420b-997a-196385424912";
    fsType = "btrfs";
    options = [
      "noauto"
      "nofail"
      "x-systemd.automount"
      "compress=zstd"
    ];
  };

  # btrbk incremental backups
  environment.etc."btrbk/btrbk.conf".source = ./btrbk.conf;

  # btrbk systemd service (runs once)
  systemd.services.btrbk = {
    description = "Incremental btrfs backups";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.btrbk}/bin/btrbk run";
    };
    # Ensure Backup disks are mounted before running
    after = [ "media-BackupData.mount" "media-BackupSystem.mount" ];
    wants = [ "media-BackupData.mount" "media-BackupSystem.mount" ];
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
