#!/bin/bash
# restic-replicate.sh
# Runs on the NAS. Copies the restic repo from Volume 1 to Volume 2 for the
# second physical copy. Uses 'restic copy' which deduplicates and is incremental
# after the first run.
#
# Run nightly, after restic-backup.sh completes.

set -euo pipefail

export RESTIC_REPOSITORY="/volume2/backup-replica/restic-mirror"
export RESTIC_PASSWORD_FILE="/root/.restic-password-mirror"
SOURCE_REPO="/volume1/backup-primary/restic-repo"
SOURCE_PASSWORD_FILE="/root/.restic-password"
LOG="/volume2/backup-replica/restic-replicate.log"

# Sanity checks
if [ ! -d "$RESTIC_REPOSITORY" ]; then
  echo "ERROR: replica repo $RESTIC_REPOSITORY does not exist. Run 'restic -r $RESTIC_REPOSITORY init' first." >&2
  exit 1
fi
if [ ! -f "$RESTIC_PASSWORD_FILE" ]; then
  echo "ERROR: replica restic password file $RESTIC_PASSWORD_FILE does not exist." >&2
  exit 1
fi

{
  echo "===== $(date -Iseconds) restic copy starting (source: $SOURCE_REPO) ====="
  restic copy --from-repo "$SOURCE_REPO" --from-password-file "$SOURCE_PASSWORD_FILE" --verbose
  echo "===== $(date -Iseconds) restic copy complete ====="
} >> "$LOG" 2>&1
