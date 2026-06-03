#!/bin/bash
# matrix-monitor-backups.sh
# Runs on Felix. Watches the NAS-mounted backup directory and posts to the
# Matrix alert room if backups are stale or missing.
#
# Run via cron: every 6 hours.
# Requires: /mnt/nas-backup-primary mounted via NFS (see setup-guide.md Phase 11)

set -uo pipefail

NAS_MOUNT="/mnt/nas-backup-primary"
MATRIX_TARGET='matrix:!ksqJXQgJ-jAmxwatiHw2ewX9flvdver1wMUABTCYFPo'
STALE_THRESHOLD_HOURS=26
NODES=("acer" "omen")

alert() {
  hermes send --to "$MATRIX_TARGET" --quiet "$1" || \
    echo "WARN: failed to send Matrix alert: $1" >&2
}

# Check mount
if ! mountpoint -q "$NAS_MOUNT"; then
  alert "🚨 NAS backup monitor: $NAS_MOUNT is not mounted"
  exit 1
fi

# Check each node's backup freshness
for NODE in "${NODES[@]}"; do
  NODE_DIR="$NAS_MOUNT/vzdump-staging/$NODE"
  if [ ! -d "$NODE_DIR" ]; then
    alert "🚨 NAS backup monitor: no backup dir for $NODE (pull hasn't run, or Proxmox unreachable)"
    continue
  fi

  LATEST=$(ls -t "$NODE_DIR" 2>/dev/null | head -1)
  if [ -z "$LATEST" ]; then
    alert "🚨 NAS backup monitor: $NODE backup dir is empty"
    continue
  fi

  LATEST_PATH="$NODE_DIR/$LATEST"
  LATEST_AGE_HOURS=$(( ($(date +%s) - $(stat -c %Y "$LATEST_PATH")) / 3600 ))

  if [ "$LATEST_AGE_HOURS" -gt "$STALE_THRESHOLD_HOURS" ]; then
    alert "🚨 NAS backup monitor: $NODE latest backup is $LATEST_AGE_HOURS hours old ($LATEST)"
  else
    echo "[$(date -Iseconds)] $NODE OK ($LATEST_AGE_HOURS hours old, $LATEST)"
  fi
done
