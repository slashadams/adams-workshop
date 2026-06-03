#!/bin/bash
# restic-check.sh
# Runs on the NAS. Weekly integrity check of the restic repo. Catches bitrot
# and corruption before you need to restore.
#
# Schedule: weekly, Sunday 3:00 AM (separate from nightly backup).

set -euo pipefail

export RESTIC_REPOSITORY="/volume1/backup-primary/restic-repo"
export RESTIC_PASSWORD_FILE="/root/.restic-password"
LOG="/volume1/backup-primary/restic-check.log"

if [ ! -d "$RESTIC_REPOSITORY" ]; then
  echo "ERROR: restic repo $RESTIC_REPOSITORY does not exist." >&2
  exit 1
fi
if [ ! -f "$RESTIC_PASSWORD_FILE" ]; then
  echo "ERROR: restic password file $RESTIC_PASSWORD_FILE does not exist." >&2
  exit 1
fi

{
  echo "===== $(date -Iseconds) restic check starting ====="
  restic check --verbose
  echo "===== $(date -Iseconds) restic check complete ====="
} >> "$LOG" 2>&1
