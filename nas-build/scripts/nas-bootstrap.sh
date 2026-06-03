#!/bin/bash
# nas-bootstrap.sh
# Runs on the NAS as root, ONCE, after ADM is up. Sets up the full backup
# infrastructure: installs restic, initializes both restic repos, generates
# password files, and prepares the staging directory.
#
# Usage: scp this script + the SSH key + the other scripts to the NAS, then run this.

set -euo pipefail

PRIMARY_REPO="/volume1/backup-primary/restic-repo"
MIRROR_REPO="/volume2/backup-replica/restic-mirror"
PRIMARY_PASSWORD_FILE="/root/.restic-password"
MIRROR_PASSWORD_FILE="/root/.restic-password-mirror"
STAGING="/volume1/backup-primary/vzdump-staging"
SCRIPT_DIR="/usr/local/bin/nas-backup"

echo "=== NAS backup infrastructure bootstrap ==="
echo

# 1. Install restic via Entware
if ! command -v restic >/dev/null 2>&1; then
  echo "restic not found. Installing via Entware..."
  opkg update
  opkg install restic
else
  echo "restic already installed: $(restic version)"
fi

# 2. Ensure staging dir exists
mkdir -p "$STAGING"
echo "Staging dir: $STAGING (exists)"

# 3. Generate password files (random, chmod 600) and initialize primary repo
if [ ! -f "$PRIMARY_PASSWORD_FILE" ]; then
  echo "Generating primary repo password and initializing $PRIMARY_REPO..."
  openssl rand -base64 32 > "$PRIMARY_PASSWORD_FILE"
  chmod 600 "$PRIMARY_PASSWORD_FILE"
  RESTIC_REPOSITORY="$PRIMARY_REPO" RESTIC_PASSWORD_FILE="$PRIMARY_PASSWORD_FILE" restic init
  echo
  echo "*** SAVE THIS PASSWORD OFFSIDE THE NAS (1Password, sealed envelope in a safe) ***"
  echo "Primary repo password: $(cat $PRIMARY_PASSWORD_FILE)"
  echo
else
  echo "Primary password file already exists at $PRIMARY_PASSWORD_FILE (skipping init)"
fi

# 4. Mirror repo (on Volume 2)
if [ ! -f "$MIRROR_PASSWORD_FILE" ]; then
  echo "Generating mirror repo password and initializing $MIRROR_REPO..."
  openssl rand -base64 32 > "$MIRROR_PASSWORD_FILE"
  chmod 600 "$MIRROR_PASSWORD_FILE"
  RESTIC_REPOSITORY="$MIRROR_REPO" RESTIC_PASSWORD_FILE="$MIRROR_PASSWORD_FILE" restic init
  echo
  echo "*** SAVE THIS PASSWORD OFFSIDE THE NAS TOO ***"
  echo "Mirror repo password: $(cat $MIRROR_PASSWORD_FILE)"
  echo
else
  echo "Mirror password file already exists at $MIRROR_PASSWORD_FILE (skipping init)"
fi

# 5. Install scripts
echo "Installing backup scripts to $SCRIPT_DIR..."
mkdir -p "$SCRIPT_DIR"
cp /tmp/nas-deploy/pull-vzdump.sh "$SCRIPT_DIR/"
cp /tmp/nas-deploy/restic-backup.sh "$SCRIPT_DIR/"
cp /tmp/nas-deploy/restic-replicate.sh "$SCRIPT_DIR/"
cp /tmp/nas-deploy/restic-check.sh "$SCRIPT_DIR/"
cp /tmp/nas-deploy/nas-backup-key "$SCRIPT_DIR/"
chmod 600 "$SCRIPT_DIR/nas-backup-key"
chmod 700 "$SCRIPT_DIR"/*.sh
chmod +x "$SCRIPT_DIR"/*.sh

# 6. Pre-populate known_hosts for the Proxmox nodes (avoids interactive prompt on first run)
mkdir -p /root/.ssh
chmod 700 /root/.ssh
ssh-keyscan -t ed25519 10.0.100.10 10.0.100.137 >> /root/.ssh/known_hosts 2>/dev/null || true
sort -u /root/.ssh/known_hosts -o /root/.ssh/known_hosts
chmod 600 /root/.ssh/known_hosts

echo
echo "=== Bootstrap complete ==="
echo
echo "Next steps:"
echo "1. Verify the SSH key from the NAS can reach the Proxmox nodes:"
echo "   ssh -i $SCRIPT_DIR/nas-backup-key -o BatchMode=yes root@10.0.100.10 'whoami'"
echo "   (Expected: 'command not allowed' or similar — the forced command rejects whoami.)"
echo
echo "2. Set up ADM Task Scheduler entries (use the JSON exports in task-scheduler-entries.json)"
echo
echo "3. Test the full chain manually:"
echo "   $SCRIPT_DIR/pull-vzdump.sh"
echo "   $SCRIPT_DIR/restic-backup.sh"
echo "   $SCRIPT_DIR/restic-replicate.sh"
echo
echo "4. SAVE YOUR RESTIC PASSWORDS OFFSIDE THE NAS NOW."
echo "   Primary: $(test -f $PRIMARY_PASSWORD_FILE && cat $PRIMARY_PASSWORD_FILE || echo 'NOT FOUND')"
echo "   Mirror:  $(test -f $MIRROR_PASSWORD_FILE && cat $MIRROR_PASSWORD_FILE || echo 'NOT FOUND')"
