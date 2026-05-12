#!/usr/bin/env bash
# Removed set -e to allow continuation on error

SOURCE="/media/BackupData/@home"
DEST="/media/BackupSystem/@home"
SNAPSHOTS_FILE="snapshots.txt"

PREV_SNAP=""

while read -r SNAP; do
  if [ -z "$PREV_SNAP" ]; then
    echo "Sending first snapshot: $SNAP"
    sudo btrfs send "$SOURCE/$SNAP" | sudo btrfs receive "$DEST" || echo "FAILED to send first snapshot: $SNAP"
  else
    echo "Sending incremental snapshot: $SNAP (parent: $PREV_SNAP)"
    sudo btrfs send -p "$SOURCE/$PREV_SNAP" "$SOURCE/$SNAP" | sudo btrfs receive "$DEST" || echo "FAILED to send incremental snapshot: $SNAP"
  fi
  PREV_SNAP="$SNAP"
done < "$SNAPSHOTS_FILE"
