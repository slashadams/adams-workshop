#!/bin/bash
# restic-backup.sh
# Runs on the NAS. Backs up the vzdump staging directory to the restic repo,
# then applies retention policy. Runs nightly after pull-vzdump.sh completes.
#
# Prereq: restic installed (via Entware on ADM), restic repo initialized,
#         /root/.restic-password contains the repo password (chmod 600).

set -euo pipefail

export RESTIC_REPOSITORY="/volume1/backup-primary/restic-repo"
export RESTIC_PASSWORD_FILE="/root/.restic-password"
STAGING="/volume1/backup-primary/vzdump-staging"
LOG="/volume1/backup-primary/restic-backup.log"

# Sanity checks
if [ ! -d "$RESTIC_REPOSITORY" ]; then
  echo "ERROR: restic repo $RESTIC_REPOSITORY does not exist. Run 'restic init' first." >&2
  exit 1
fi
if [ ! -f "$RESTIC_PASSWORD_FILE" ]; then
  echo "ERROR: restic password file $RESTIC_PASSWORD_FILE does not exist." >&2
  exit 1
fi
if [ ! -d "$STAGING" ]; then
  echo "ERROR: staging dir $STAGING does not exist. Did pull-vzdump.sh run?" >&2
  exit 1
fi

{
  echo "===== $(date -Iseconds) restic backup starting ====="
  restic backup "$STAGING" --tag nightly --verbose
  echo "===== retention prune starting ====="
  restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune --verbose
  echo "===== $(date -Iseconds) restic backup complete ====="
} >> "$LOG" 2>&1
