#!/bin/bash
# asustor-nas-backup-pull
# One-time install of the NAS backup-pull SSH public key on a Proxmox node.
#
# Usage: ./install-key.sh <proxmox-host>
#   proxmox-host: hostname or IP of the Proxmox node (e.g. 10.0.100.10 or 10.0.100.137)
#
# This script:
#   1. Copies the public key to the Proxmox node's root authorized_keys
#   2. Wraps it in a forced command that ONLY allows rsync to /var/lib/vz/dump/
#   3. Tests that the constrained key works as expected
#
# Requirements:
#   - You have the Proxmox node's root password
#   - sshpass is installed (or you'll be prompted for the password)
#   - The Proxmox node accepts password-based SSH (default Proxmox install does)

set -euo pipefail

KEY_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBKEY_FILE="$KEY_DIR/nas-backup-key.pub"
PRIVKEY_FILE="$KEY_DIR/nas-backup-key"

if [ ! -f "$PUBKEY_FILE" ] || [ ! -f "$PRIVKEY_FILE" ]; then
  echo "ERROR: key files not found in $KEY_DIR"
  exit 1
fi

if [ $# -ne 1 ]; then
  echo "Usage: $0 <proxmox-host>"
  exit 1
fi

PROXMOX_HOST="$1"
PROXMOX_USER="root"
AUTHORIZED_KEYS="/root/.ssh/authorized_keys"

# The forced command restricts the key to ONLY this rsync invocation.
# No shell. No arbitrary commands. Just: receive an rsync stream of /var/lib/vz/dump/.
FORCED_CMD='command="rsync --server -logDtpre.iLsfxCIvu --delete . /var/lib/vz/dump/",from="10.0.100.50",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty'

# Build the full authorized_keys line
PUBKEY_BODY=$(cat "$PUBKEY_FILE")
FULL_KEY_LINE="$FORCED_CMD $PUBKEY_BODY"

echo "=== Installing constrained SSH key on $PROXMOX_HOST ==="
echo
echo "This will add the following line to $PROXMOX_USER@$PROXMOX_HOST:$AUTHORIZED_KEYS:"
echo
echo "  $FULL_KEY_LINE"
echo

# Check if key already installed (idempotent)
if ssh -o StrictHostKeyChecking=accept-new -i "$PRIVKEY_FILE" "$PROXMOX_USER@$PROXMOX_HOST" "echo test" 2>/dev/null; then
  echo "Key already installed and working on $PROXMOX_HOST. Skipping install."
  exit 0
fi

# Read the password (or use sshpass)
if command -v sshpass >/dev/null 2>&1; then
  read -s -p "Enter root password for $PROXMOX_HOST: " PROXMOX_PASS
  echo
  export SSHPASS="$PROXMOX_PASS"
  SSH_COPY="sshpass -e ssh"
  SCP_COPY="sshpass -e scp"
else
  echo "sshpass not installed. Install with: apt install sshpass"
  echo "Or run this script with the password available via SSH_ASKPASS."
  exit 1
fi

# Append the key to authorized_keys
$SSH_COPY -o StrictHostKeyChecking=accept-new "$PROXMOX_USER@$PROXMOX_HOST" \
  "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF '$FULL_KEY_LINE' ~/.ssh/authorized_keys 2>/dev/null || echo '$FULL_KEY_LINE' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key installed successfully'"

echo
echo "=== Testing constrained key ==="
echo
echo "Test 1: Try a non-rsync command (should FAIL — key only allows rsync)..."
if ssh -i "$PRIVKEY_FILE" -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" "whoami" 2>&1 | grep -q "command not allowed\|forced command\|not allowed"; then
  echo "  PASS: Non-rsync command was correctly rejected."
else
  echo "  Result: $(ssh -i "$PRIVKEY_FILE" -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" "whoami" 2>&1 | head -1)"
  echo "  (Expected: 'command not allowed' or similar — if you got a username, the forced command isn't working.)"
fi

echo
echo "Test 2: Try rsync to /var/lib/vz/dump/ (should SUCCEED)..."
if rsync -a -e "ssh -i $PRIVKEY_FILE -o BatchMode=yes" "rsync://$PROXMOX_USER@$PROXMOX_HOST/." /tmp/rsync-test/ 2>&1 | head -3; then
  echo "  Rsync connection successful — backup-pull path is open."
fi

echo
echo "=== Installation complete on $PROXMOX_HOST ==="
