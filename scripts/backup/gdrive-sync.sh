#!/run/current-system/sw/bin/bash
set -e

# Use haitv's rclone config when running as root
export RCLONE_CONFIG=/home/haitv/.config/rclone/rclone.conf

RCLONE=/run/current-system/sw/bin/rclone
DRIVE=GGDRIVE

# Optimized rclone parameters for large transfers
RCLONE_OPTS="
  --transfers=16 \
  --checkers=32 \
  --drive-chunk-size=128M \
  --drive-upload-cutoff=64M \
  --max-backlog=50000 \
  --tpslimit=10 \
  --tpslimit-burst=10 \
  --drive-pacer-min-sleep=100ms \
  --drive-pacer-burst=200 \
  --low-level-retries=20 \
  --retries=10 \
  --retries-sleep=20s \
  --timeout=10m \
  --expect-continue-timeout=10m \
  --bwlimit=150M \
  --progress \
  --fast-list"

echo "=================================="
echo "Google Drive Backup Started"
echo "Time: $(date)"
echo "=================================="

# Find latest snapshots
LATEST_HOME=$(ls -1d /home/.snapshots/home.* 2>/dev/null | sort -r | head -1)
LATEST_ARCHIVED=$(ls -1d /media/Data/.snapshots/archived.* 2>/dev/null | sort -r | head -1)
LATEST_MYDATA=$(ls -1d /media/Data/.snapshots/mydata.* 2>/dev/null | sort -r | head -1)

# Sync home directory from latest snapshot
if [ -n "$LATEST_HOME" ]; then
  echo ""
  echo "Syncing home from snapshot: $LATEST_HOME"
  $RCLONE sync "$LATEST_HOME/haitv" $DRIVE:backups/haitv \
    $RCLONE_OPTS \
    --exclude ".codex/**" \
    --exclude ".docker/**" \
    --exclude ".dotnet/**" \
    --exclude ".cache/**" \
    --exclude ".local/share/Trash/**"
else
  echo "WARNING: No home snapshot found, skipping"
fi

# Sync data archived folder from latest snapshot
if [ -n "$LATEST_ARCHIVED" ]; then
  echo ""
  echo "Syncing archived from snapshot: $LATEST_ARCHIVED"
  $RCLONE sync "$LATEST_ARCHIVED" $DRIVE:backups/archived $RCLONE_OPTS
else
  echo "WARNING: No archived snapshot found, skipping"
fi

# Sync data mydata folder from latest snapshot
if [ -n "$LATEST_MYDATA" ]; then
  echo ""
  echo "Syncing mydata from snapshot: $LATEST_MYDATA"
  $RCLONE sync "$LATEST_MYDATA" $DRIVE:backups/mydata $RCLONE_OPTS
else
  echo "WARNING: No mydata snapshot found, skipping"
fi

echo ""
echo "=================================="
echo "Google Drive backup completed successfully"
echo "Time: $(date)"
echo "=================================="
