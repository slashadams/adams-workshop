#!/bin/bash
# pull-vzdump.sh
# Runs on the NAS. Pulls /var/lib/vz/dump/ from each Proxmox node via rsync over SSH.
# Uses the constrained SSH key installed by install-key.sh (forced-command rsync only).
#
# Run from cron: nightly, after vzdump completes on each Proxmox node.
# Default Proxmox vzdump schedule is 02:00; this runs at 02:30 to give it time to finish.

set -euo pipefail

# --- Config ---
KEY="/root/.ssh/nas-backup-key"
KNOWN_HOSTS="/root/.ssh/known_hosts"
STAGING="/volume1/backup-primary/vzdump-staging"

# Proxmox nodes (hostname or IP, must match what ssh-keyscan sees)
NODES=(
  "10.0.100.10:acer"
  "10.0.100.137:omen"
)

# SSH options: BatchMode=yes so it never prompts; StrictHostKeyChecking=yes for safety
SSH_OPTS=(-i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10)

# --- Preflight ---
if [ ! -f "$KEY" ]; then
  echo "ERROR: SSH key not found at $KEY" >&2
  exit 1
fi

mkdir -p "$STAGING"

# --- Pull from each node ---
EXIT_CODE=0
for ENTRY in "${NODES[@]}"; do
  HOST="${ENTRY%%:*}"
  LABEL="${ENTRY##*:}"
  DEST="$STAGING/$LABEL"

  mkdir -p "$DEST"
  echo "[$(date -Iseconds)] Pulling from $HOST -> $DEST"

  # rsync over ssh with the constrained key. The forced command on the Proxmox
  # side ONLY allows this exact rsync invocation, so even if the key leaks,
  # the worst an attacker can do is pull /var/lib/vz/dump/ (which is the
  # whole point of the key).
  if rsync -a --delete \
    -e "ssh ${SSH_OPTS[*]}" \
    "root@${HOST}:/" "$DEST/" 2>&1; then
    echo "[$(date -Iseconds)] $HOST pull OK"
  else
    echo "[$(date -Iseconds)] $HOST pull FAILED" >&2
    EXIT_CODE=1
  fi
done

exit $EXIT_CODE
