# NAS Backup Scripts — Asustor AS3304T v2

Pre-built scripts and config files for the Asustor NAS backup infrastructure. Ready to deploy as soon as the NAS is online.

**Note:** The SSH private key for backup pulls is **not** included in this repository. You'll generate it locally during install (Step 1) so each install gets a unique key. The constrained design — forced-command SSH key restricted to `rsync /var/lib/vz/dump/` — means a leaked key is limited in what it can do, but the principle is to never put private keys in public repos.

## Install order

### Step 1: Generate SSH key on Felix (one-time)

```bash
# On Felix
mkdir -p /root/felix/scripts/nas-deploy
cd /root/felix/scripts/nas-deploy
ssh-keygen -t ed25519 -C "asustor-nas-backup-pull" -f ./nas-backup-key -N ""
chmod 600 nas-backup-key
```

This produces `nas-backup-key` (private, keep on Felix AND copy to NAS later) and `nas-backup-key.pub` (public, will be installed on the Proxmox nodes).

### Step 2: Install SSH key on Proxmox nodes (Felix-side, run once per node)

```bash
# From Felix
cd /root/felix/scripts/nas-deploy

# Install sshpass if you don't have it
apt install sshpass

# Run the installer against each Proxmox node
./install-key.sh 10.0.100.10   # Acer Nitro
./install-key.sh 10.0.100.137  # HP Omen
```

The installer:
- Reads the public key from `nas-backup-key.pub`
- Wraps it in a forced-command sshd directive
- Appends it to the Proxmox node's `root@pam` authorized_keys
- Tests that the constrained key works (rsync works, whoami fails)

You'll need the Proxmox root password each time. The key is added permanently to authorized_keys; you don't need the password again after this.

### Step 3: Bootstrap the NAS (run once, on the NAS, after ADM is up)

```bash
# From Felix: copy the scripts and SSH key to the NAS
scp -r /root/felix/scripts/nas-deploy/* root@<NAS-IP>:/tmp/nas-deploy/

# SSH into the NAS
ssh root@<NAS-IP>

# On the NAS, run the bootstrap
chmod +x /tmp/nas-deploy/*.sh
/tmp/nas-deploy/nas-bootstrap.sh
```

`nas-bootstrap.sh` will:
- Install restic via Entware
- Generate random passwords for both restic repos (primary + mirror)
- Initialize both restic repos
- Install the backup scripts to `/usr/local/bin/nas-backup/`
- Pre-populate `~/.ssh/known_hosts` for the Proxmox nodes
- **Print the passwords to the terminal — save them somewhere safe (1Password, sealed envelope in a safe) before closing the session**

### Step 4: Configure ADM Task Scheduler (on the NAS, run once)

The JSON file `task-scheduler-entries.json` contains the four scheduled tasks for the NAS. ADM doesn't support direct JSON import for tasks, so recreate them manually in **Control Panel → Task Scheduler → Add → Scheduled Task → User-defined script**. The JSON is a reference, not an import format.

**Four tasks to create on the NAS:**

| Name | Schedule | Script |
|---|---|---|
| NAS: pull vzdump from Proxmox nodes | Daily 02:30 | `/usr/local/bin/nas-backup/pull-vzdump.sh` |
| NAS: restic backup | Daily 03:30 | `/usr/local/bin/nas-backup/restic-backup.sh` |
| NAS: restic replicate to Volume 2 | Daily 05:00 | `/usr/local/bin/nas-backup/restic-replicate.sh` |
| NAS: restic check (weekly integrity) | Sunday 03:00 | `/usr/local/bin/nas-backup/restic-check.sh` |

Run all four as `root`.

### Step 5: Configure Proxmox-side vzdump (on each Proxmox node, run once)

In each Proxmox node's web UI: **Datacenter → Backup → Add**

- Storage: `local`
- Schedule: Daily, 02:00
- Selection Mode: All
- Mode: Snapshot
- Compression: ZSTD
- Notification: None (NAS-side monitor handles this)

Set this on BOTH nodes (Acer Nitro 10.0.100.10 and HP Omen 10.0.100.137).

### Step 6: Set up Felix-side backup monitor (on Felix, run once)

```bash
# Add the cron entry
crontab -e
# Append:
0 */6 * * * /root/felix/scripts/nas-deploy/matrix-monitor-backups.sh >> /var/log/nas-backup-monitor.log 2>&1

# Mount the NAS's backup-primary share (one-time)
echo "<NAS-IP>:/volume1/backup-primary /mnt/nas-backup-primary nfs defaults,_netdev 0 0" >> /etc/fstab
mkdir -p /mnt/nas-backup-primary
mount -a
```

This script checks every 6 hours that the NAS has backups less than 26 hours old from both Proxmox nodes. Alerts to the Matrix room if anything's stale.

## What you should have at the end

- ✅ Constrained SSH key on both Proxmox nodes (forced rsync command only)
- ✅ restic installed and configured on the NAS
- ✅ Two restic repos initialized (primary on Volume 1, mirror on Volume 2)
- ✅ Four ADM scheduled tasks pulling, backing up, replicating, and checking
- ✅ Proxmox-side vzdump running nightly at 02:00 on both nodes
- ✅ Felix-side monitor posting to Matrix if anything goes stale
- ✅ The restic passwords saved somewhere offline (in 1Password, a sealed envelope, etc.)

## File reference

| File | Purpose |
|---|---|
| `install-key.sh` | One-time key installer for Proxmox nodes |
| `nas-bootstrap.sh` | One-time NAS setup (restic install, repo init, script install) |
| `pull-vzdump.sh` | Nightly: pulls vzdump output from Proxmox nodes to NAS |
| `restic-backup.sh` | Nightly: backs up vzdump staging to restic repo |
| `restic-replicate.sh` | Nightly: copies restic repo to Volume 2 |
| `restic-check.sh` | Weekly: validates restic repo integrity |
| `matrix-monitor-backups.sh` | Felix-side: alerts to Matrix if backups are stale |
| `task-scheduler-entries.json` | Reference for ADM Task Scheduler setup |

**Not in this repo (generated locally during install):**
- `nas-backup-key` — SSH private key. Stays on Felix and copies to NAS only.
- `nas-backup-key.pub` — SSH public key. Installed on Proxmox nodes by `install-key.sh`.

## Security model

The SSH key has a forced command baked into the Proxmox-side `authorized_keys`. Even if the key is leaked:

- ❌ Cannot open a shell
- ❌ Cannot run arbitrary commands
- ❌ Cannot port-forward, X11-forward, or agent-forward
- ✅ Can ONLY run: `rsync --server ... /var/lib/vz/dump/`

So the worst case of key compromise is "someone can pull your backup files" — which is exactly what the key is supposed to do. The forced command is the real security boundary, not the passphrase (which is empty by design — backup-agent keys are installed once and used forever; passphrase just adds a moving part that can fail).

The key is also restricted to source IP `10.0.100.50` (the NAS's static IP, which you'll set in Phase 2 of `setup-guide.md`). So even if the key leaks, an attacker would also need to be on your LAN with a spoofed source IP — not impossible but a meaningful additional barrier.

## What can still go wrong

- **Both Proxmox nodes are down simultaneously:** pull fails, alert fires. The next day, if they're still down, alert fires again. Backups stop.
- **NAS itself is down:** Felix's monitor can't mount the share. Alert fires. The Proxmox nodes keep backing up locally, but nothing is being pulled.
- **Both drives in Volume 1 die:** the restic repo is gone. Mitigation: monthly external USB drive rotation of the primary repo to an offsite location.
- **Restic password is lost:** the backups are unreadable. **SAVE THE PASSWORDS OFFSIDE THE NAS.**

---
