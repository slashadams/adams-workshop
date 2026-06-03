# NAS Setup — Asustor Drivestor 4 Pro Gen2 (AS3304T v2)

**Status:** Hardware picked. Doc covers ADM (Asustor Data Master) setup + Btrfs volume configuration + NFS/SMB/Syncthing/restic + Proxmox integration + Matrix alerts.

**Hardware:** Asustor AS3304T v2 (Drivestor 4 Pro Gen2) — 4-bay, Realtek RTD1619B quad-core, 2GB DDR4 (soldered, non-upgradeable), 2.5GbE + your 4× 4TB 3.5" drives.

**Approximate cost:** ~$340-380 (NAS unit only — your 4× 4TB drives are the data tier). Same price at Amazon and B&H Photo, both with free shipping; Amazon typically arrives faster.

---

## What this gets you

- **NAS unit:** Asustor AS3304T v2, 4-bay, 2.5GbE, 2GB RAM (soldered)
- **OS:** ADM (Asustor Data Manager) — web UI, app catalog, no command line required for the basics
- **Filesystem:** Btrfs (ADM default) — supports checksumming, snapshots, and pooling. Different from ZFS but similar reliability story
- **Topology (what we're building):**
  - 2× 4TB drives as a Btrfs mirror = 4TB usable (Pool 1: backups)
  - 2× 4TB drives as a Btrfs mirror = 4TB usable (Pool 2: personal + Proxmox node storage + Syncthing receive)
  - Cross-pool snapshot replication for backups
- **Drive topology per Btrfs docs:** ADM's storage manager handles Btrfs RAID1 (mirror) configuration through the web UI. You don't need to use Btrfs RAID5/6 if you don't want to.

---

## Pool topology

ADM's Storage Manager creates "Volumes" out of disks. Each volume is a Btrfs filesystem with a redundancy profile. For your use case:

- **Volume 1 (backup-primary):** Disks 1 + 2, Btrfs RAID1 (mirror), 4TB usable
- **Volume 2 (backup-replica):** Disks 3 + 4, Btrfs RAID1 (mirror), 4TB usable

**Important:** Asustor's Btrfs implementation in ADM does NOT support the kind of cross-pool snapshot replication that TrueNAS does out of the box. To replicate from Volume 1 to Volume 2, you'll have one of these options:

1. **restic on the NAS replicates to a second restic repo on Volume 2** — clean, deduplicated, versioned. Restic on ADM can be installed via the App Center or via SSH + Entware.
2. **Rsync scheduled via Task Scheduler** — simpler, no dedup, but easy to set up. Runs nightly to copy the restic repo from Volume 1 to Volume 2.
3. **Btrfs send/receive via SSH** — most efficient, but most complex. Requires SSH access and command-line work.

**Recommendation:** Option 1. Restic to a second repo. It handles dedup, integrity checks, and version history in one tool.

---

## Setup phases

### Phase 1: Unbox and physical install (~15 min)

1. **Inventory:** AS3304T v2 unit, power cord, ethernet cable, quick-start guide, 4× drive caddies.
2. **Install the 4× 4TB drives into caddies.** Each caddy has 4 screws (or is toolless, depending on revision). Drive label facing up, SATA connector toward the back of the caddy. Slide each caddy into the front bays until it clicks.
3. **Connect ethernet** to your LAN (your UniFi switch or directly to the gateway).
4. **Power on.** The front-panel LED will indicate boot status.

### Phase 2: Initial ADM setup via web (~20 min)

1. **Find the NAS on your network.** Asustor provides "Control Center" (Windows/Mac) software that finds the NAS. Or check your router's DHCP leases for the new device.
2. **Open browser to the NAS's IP** (e.g., `http://192.168.1.x:8000`). ADM's initial setup wizard appears.
3. **Follow the wizard:**
   - Set admin password (strong, this is the master credential)
   - Configure network (static IP recommended — your NAS should be at a fixed address like 10.0.100.50, not DHCP)
   - Configure time zone (US/Eastern — your timezone)
   - **Skip** registration / cloud setup if offered (you said no cloud, and Asustor's EZ-Connect lets you access the NAS over the internet — you don't need that)
4. **Activate ADM** — may require a one-time online check; if you want to keep the NAS fully air-gapped, this is the only step that needs internet.

### Phase 3: Create the Btrfs volumes (~15 min)

1. **Storage Manager → Volume → Create**
2. **Volume 1 (backup-primary):**
   - Select Disks 1 + 2
   - RAID Level: Btrfs RAID1 (mirror)
   - Name: `backup-primary`
   - Encryption: optional (not recommended for backups unless you have a key management plan)
3. **Repeat for Volume 2 (backup-replica):**
   - Select Disks 3 + 4
   - RAID Level: Btrfs RAID1 (mirror)
   - Name: `backup-replica`
4. **Wait for volume creation.** Initializing a 4TB mirror takes 30-90 minutes depending on drive size and speed. You can do other setup while it runs.

### Phase 4: Users + SMB share for personal files (~10 min)

1. **Access Control → Users → Add:**
   - Username: `adam`
   - Password: strong password
   - Description: your name
   - **Grant access to: `backup-replica`** (so your user can read/write the personal storage pool)
2. **Access Control → Shared Folders → Add:**
   - Name: `Personal`
   - Volume: `backup-replica`
   - **Permission: keep "adam" as the only user with full access**
3. **Services → SMB → Enable** (Windows File Sharing)
   - **Workgroup:** match your Windows workgroup (default `WORKGROUP`)
   - Browse the `Personal` folder
4. **Test from Windows PC:** File Explorer → `\\<NAS-IP>\Personal` → enter credentials → should see the share. Map it as a network drive if you want it persistent (`Map Network Drive` in File Explorer).

### Phase 5: NFS for Proxmox nodes (~10 min)

1. **Services → NFS → Enable**
2. **Access Control → Shared Folders → Personal (the folder you just made) → NFS Permissions → Add:**
   - **Allowed IP:** `10.0.100.0/24` (your LAN, including the Proxmox nodes)
   - **Read/Write:** yes
   - **Root squash:** map root to nobody (security best practice — Proxmox can still write as a non-root user)
3. **Create a second shared folder for Proxmox node storage:**
   - Name: `ProxmoxStorage`
   - Volume: `backup-replica`
   - NFS permissions: same as above (10.0.100.0/24, read-write, root squashed)
4. **Test from a Proxmox node shell:**
   ```bash
   showmount -e <NAS-IP>
   mount -t nfs <NAS-IP>:/volume1/ProxmoxStorage /mnt/nas-storage
   ls /mnt/nas-storage
   umount /mnt/nas-storage
   ```

### Phase 6: Syncthing for phone backup (~15 min)

1. **App Central → search "Syncthing" → Install**
2. **Open Syncthing** from the ADM desktop. Web UI loads (default port 8384).
3. **Get the Syncthing Device ID** (Actions → Show Device ID).
4. **On your Samsung Galaxy S26 Ultra:**
   - Install Syncthing from F-Droid (recommended) or Play Store
   - Open the app, allow storage + photos permissions
   - Add the NAS as a remote device using the Device ID
5. **On the NAS Syncthing web UI:**
   - Add Folder: `phone-camera` → path `/volume1/backup-replica/phone-sync/photos/`
   - Share with the phone device
   - On the phone, accept the share, point to your DCIM/Camera folder
6. **On your Windows PC:**
   - Install Syncthing Tray (Microsoft Store) or from syncthing.net
   - Add the NAS as a remote device (same Device ID, or generate a new one for the PC)
   - On the NAS, share `/volume1/backup-replica/phone-sync/photos/` with the Windows device
   - On Windows, accept the share, point to `C:\Users\Adam\Syncthing\photos`

Now everything syncs: phone → NAS → Windows PC. Take a photo, it appears in the NAS folder and your PC folder within seconds.

### Phase 7: restic on the NAS for Proxmox backups (~30 min)

**Restic doesn't have a one-click install in ADM. Two options:**

**Option A: Install via Entware + opkg (recommended for ADM)**

ADM is Debian-based, but you can't `apt install` directly. Asustor provides Entware as a package manager for ADM. To get restic:

1. **App Central → search "Entware" → Install**
2. **SSH into the NAS** (Services → Terminal → Enable SSH first)
3. SSH as `root` with your admin password
4. `opkg update && opkg install restic`
5. Initialize the restic repo:
   ```bash
   restic -r /volume1/backup-primary/restic-repo init
   ```
6. **Save the restic password** somewhere safe (1Password, a sealed envelope in a safe, etc.). Losing it = unreadable backups.

**Option B: Static binary download**

If Entware isn't available, you can download a static restic binary from GitHub releases. Less clean, but works.

**Schedule nightly restic backup via ADM Task Scheduler:**

1. **Control Panel → Task Scheduler → Add → Scheduled Task → User-defined script**
2. **Run as:** root
3. **Schedule:** Daily, 2:00 AM
4. **Script:**
   ```bash
   #!/bin/bash
   export RESTIC_REPOSITORY=/volume1/backup-primary/restic-repo
   export RESTIC_PASSWORD_FILE=/root/.restic-password
   restic backup /volume1/backup-primary/vzdump-staging
   restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune
   ```
5. **Enabled:** yes

**Schedule weekly restic check:**

Same as above, but:
- Schedule: Weekly, Sunday 3:00 AM
- Script:
  ```bash
  #!/bin/bash
  export RESTIC_REPOSITORY=/volume1/backup-primary/restic-repo
  export RESTIC_PASSWORD_FILE=/root/.restic-password
  restic check
  ```

### Phase 8: Cross-pool replication (restic to second repo) (~10 min)

**Why:** Protects against bitrot, accidental deletion, and double-drive failure in Volume 1. The backup of the backups.

**Approach:** Run a second restic repo on Volume 2, and have a nightly job copy the repo from Volume 1 to Volume 2.

1. **Initialize second restic repo on Volume 2:**
   ```bash
   restic -r /volume2/backup-replica/restic-mirror init
   ```
2. **Add a Task Scheduler entry:**
   - Schedule: Daily, 4:00 AM
   - Script:
     ```bash
     #!/bin/bash
     export RESTIC_REPOSITORY=/volume2/backup-replica/restic-mirror
     export RESTIC_PASSWORD_FILE=/root/.restic-password-mirror
     restic copy --from-repo /volume1/backup-primary/restic-repo --from-password-file /root/.restic-password
     ```
   - **`restic copy`** is the right command — it copies snapshots between repos, deduplicating as it goes.

The first run takes a while (copies the entire repo). Subsequent runs are incremental — only new snapshots are copied.

### Phase 9: Proxmox-side storage config (~5 min per node)

**On each Proxmox node, in the web UI:**

1. **Datacenter → Storage → Add → NFS**
   - ID: `nas-storage`
   - Server: `<NAS-IP>` (e.g., 10.0.100.50)
   - Export: `/volume1/ProxmoxStorage`
   - Content: `Disk image`, `ISO image`, `Container`, `Templates`
   - Enabled: yes
2. **Verify:** Datacenter → Storage should show `nas-storage` with the right content types and enough free space.

### Phase 10: Proxmox backup schedule (~5 min per node)

1. **Datacenter → Backup → Add**
   - Storage: `Local` (default)
   - Schedule: Daily, 02:00
   - Selection Mode: All
   - Mode: Snapshot
   - Compression: ZSTD
   - Notification mode: Skip (we'll monitor from the NAS side instead)
2. **Note:** vzdump creates files like `dump-vzdump-lxc-101-2025_06_02-02_00_00.tar.zst` in the configured backup directory.

**Then add an SSH pull from the NAS to bring backups onto the NAS:**

1. **On the NAS, SSH to the Proxmox node and pull the vzdump output:**
   - Add an SSH key from the NAS to each Proxmox node (one-time setup)
   - Create a script on the NAS:
     ```bash
     #!/bin/bash
     # Pull vzdump output from both Proxmox nodes
     rsync -a root@10.0.100.10:/var/lib/vz/dump/ /volume1/backup-primary/vzdump-staging/acer/
     rsync -a root@10.0.100.137:/var/lib/vz/dump/ /volume1/backup-primary/vzdump-staging/omen/
     ```
   - Schedule via Task Scheduler: Daily, 2:30 AM (after vzdump completes)
2. **Restic on the NAS then backs up `/volume1/backup-primary/vzdump-staging/`** as configured in Phase 7.

This gives you: Proxmox backs up locally → NAS pulls backups nightly → restic versions them → restic copies to second pool.

### Phase 11: Matrix alert integration (~20 min)

The UniFi monitor script you already have at `/root/felix/unifi-monitor/check.py` can be adapted. New script: `backup-monitor.sh` on Felix.

```bash
#!/bin/bash
# Check if a fresh backup landed in the last 26 hours

# Mount the NAS's backup-primary share on Felix (one-time setup in /etc/fstab)
NAS_NFS=/mnt/nas-backup-primary
LATEST=$(ls -t $NAS_NFS/vzdump-staging/ 2>/dev/null | head -1)

if [ -z "$LATEST" ]; then
  hermes send --to "matrix:!ksqJXQgJ-jAmxwatiHw2ewX9flvdver1wMUABTCYFPo" \
    "🚨 NAS backup monitor: no backups found on backup-primary"
  exit 1
fi

# Check both Proxmox nodes' backup dirs
for NODE in acer omen; do
  LATEST_NODE=$(ls -t $NAS_NFS/vzdump-staging/$NODE/ 2>/dev/null | head -1)
  if [ -z "$LATEST_NODE" ]; then
    hermes send --to "matrix:!ksqJXQgJ-jAmxwatiHw2ewX9flvdver1wMUABTCYFPo" \
      "🚨 NAS backup monitor: no backups found from $NODE"
    continue
  fi
  AGE_HOURS=$(( ($(date +%s) - $(stat -c %Y $NAS_NFS/vzdump-staging/$NODE/$LATEST_NODE)) / 3600 ))
  if [ $AGE_HOURS -gt 26 ]; then
    hermes send --to "matrix:!ksqJXQgJ-jAmxwatiHw2ewX9flvdver1wMUABTCYFPo" \
      "🚨 NAS backup monitor: $NODE latest backup is $AGE_HOURS hours old"
  fi
done
echo "Backup monitor OK"
```

**Cron entry on Felix:** every 6 hours.

**One-time setup: mount the NAS on Felix via NFS**

Add to `/etc/fstab` on Felix:
```
<NAS-IP>:/volume1/backup-primary /mnt/nas-backup-primary nfs defaults,_netdev 0 0
```

Then `mount -a` to test.

---

## Summary

**After all 11 phases, you have:**

- ✅ Asustor AS3304T v2 with 4× 4TB drives in 2× Btrfs RAID1 mirrors
- ✅ Volume 1: versioned Proxmox backups (restic), replicated to Volume 2
- ✅ Volume 2: personal files (SMB to Windows), Proxmox node storage (NFS), phone sync (Syncthing)
- ✅ Cross-pool replication via restic copy
- ✅ Matrix alerts when backups go stale
- ✅ Samsung Galaxy S26 Ultra, Windows PC, and both Proxmox nodes all using the NAS

**What you don't get with this build:**

- ❌ Offsite backup (you explicitly didn't want cloud). Mitigation: monthly external USB drive rotation of the restic repo.
- ❌ TrueNAS-style ZFS send/receive (Btrfs send/receive is possible but ADM doesn't expose it cleanly). Restic copy achieves the same end result.
- ❌ Real-time replication to a second location.

**Things that are different from the TrueNAS version:**

- ADM is a web-UI-driven OS, not a Debian box. SSH + Entware gives you command-line access for restic, but you don't manage the OS at the Linux level.
- Btrfs instead of ZFS. Both are copy-on-write filesystems with checksumming. Btrfs is what Asustor ships; ZFS would require wiping ADM and installing TrueNAS (which the AS3304T can run, but that's a different build).
- ADM's app catalog is more curated than TrueNAS Scale's. Syncthing is available, Plex/Jellyfin are available. Less choice, but everything you actually need is there.
- 2GB RAM is comfortable for the basic setup (ADM + SMB + NFS + Syncthing + restic). Don't try to run Plex transcoding or VMs on this. The NAS does storage; Proxmox does compute.

**Next steps:**

1. Order the Asustor AS3304T v2 (~$340-380 on Amazon — same price at B&H Photo, both with free shipping; Amazon typically arrives faster. B&H offers 4-payment financing through B&H Pay Later / Affirm; Amazon also accepts Affirm if you have the Affirm card)
2. While waiting, finish the SSH access setup to the Proxmox nodes (we were mid-thread on this — the vzdump-pull script needs it)
3. When the unit arrives, follow phases 1-11 in order
4. After first successful backup, test a restore (restore an LXC to a temporary VM and verify it boots)

---

## Open questions / decisions deferred

- **External USB rotation schedule** — when, where the drive lives, who rotates it
- **Whether ADM's bundled EZ-Sync is preferable to Syncthing for your phone** — EZ-Sync is Asustor's own sync tool, simpler UI. Syncthing is more flexible. Both work; the doc uses Syncthing because it's what you asked about.
- **Whether to flash TrueNAS Scale onto the AS3304T** — possible, but loses ADM's polish. Not recommended unless you outgrow ADM.
- **How to back up the NAS itself** — if both drives in Volume 1 die, the restic repo is gone. ZFS mirror (in TrueNAS) handles this; Btrfs RAID1 in ADM does too, for single-drive failure. For double-drive failure in the same volume, mitigation is the external USB rotation.
- **2GB RAM is the ceiling.** Asustor's consumer Drivestor line solders RAM to the motherboard — there is no SO-DIMM slot on the AS3304T v2. If 2GB becomes a constraint in 3+ years, the upgrade path is a new NAS, not a RAM swap. For the planned use (storage + Syncthing + light apps), 2GB should be sufficient for the lifetime of the device.

---
