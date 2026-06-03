# NAS Build & Setup — Adam's Homelab Backup Target

**Status:** Parts list confirmed, ready to order. Build doc covers assembly + TrueNAS Scale setup + Proxmox backup integration + Syncthing + Matrix alerts.

**Estimated build cost:** ~$330-535 new (parts only — your 4× 4TB drives are free), depending on where you source the board/case and PSU choice

---

## Parts List

| # | Part | Specific SKU | Price (approx) | Notes |
|---|---|---|---|---|
| 1 | Motherboard | CWWK N100 NAS Monster Board (4× 2.5GbE, 6× SATA 3.0, 2× M.2 NVMe) | $195-205 | Fan included. N100 is the right chip — 4 cores, 6W TDP, plenty for NAS duty. Prices vary by seller (CWWK direct via Amazon, AliExpress, or AliExpress) — shop around. |
| 2 | Case | Jonsbo N3 Mini-ITX NAS Chassis (8× 3.5" + 1× 2.5" hot-swap bays) | $130-170 | Black or silver. Built-in fans + SFX PSU support. AliExpress ~$117+shipping, Amazon US ~$165-170, Newegg ~$140-150. |
| 3 | RAM | Crucial 8GB DDR5-4800 SO-DIMM (CT8G48C40S5) | $20-30 | 8GB is plenty for TrueNAS + SMB + NFS + Syncthing + restic. |
| 4 | Boot SSD | Kingston 128GB A400 SATA 2.5" (or any 120-128GB SATA SSD) | $15-25 | Separate from data pool. OS lives here. |
| 5 | PSU | Corsair SF450 or similar 450W SFX (or use a 12V barrel adapter if board supports it) | $50-60 | SFX required for Jonsbo N3. Check board specs — CWWK N100 may take 12V DC directly via 4-pin Molex, in which case a $25 12V 90W adapter works instead. |
| 6 | CPU cooler | Low-profile 115X-compatible (Cooler Master G200P or similar, 65W TDP) | $20-30 | CWWK includes a basic fan; an aftermarket low-profile is quieter. Optional. |
| 7 | SATA cables | 4× SATA cables (often included with case/motherboard) | $0-15 | Confirm what's in the box; spares are cheap. |

**Total:** ~$430-535 new, depending on PSU choice and where you buy the board/case.

**Cheapest realistic build** (CWWK direct via AliExpress for board, AliExpress for case, 12V barrel adapter instead of SFX PSU, no aftermarket cooler): ~$330-380
**Mid-range build** (Amazon for everything, SFX PSU, no aftermarket cooler): ~$450-500
**Top end** (Amazon Prime, all add-ons, aftermarket cooler): ~$520-550

### Where to buy (Amazon links to specific listings)

Search Amazon for these exact model numbers:

- `CWWK N100 NAS Monster Board 6 SATA 4 2.5GbE` — Amazon ASIN: B0CPTQGX4Q
- `Jonsbo N3 Mini-ITX NAS case` — Amazon ASIN: B0CMVBMVHT
- `Crucial 8GB DDR5-4800 SO-DIMM CT8G48C40S5`
- `Kingston 128GB A400 SATA SSD`
- `Corsair SF450 SFX PSU` (only if not using barrel adapter)

### Before you order: confirm one thing

The CWWK N100 board has a 4-pin Molex-style DC input. Some versions accept 12V DC directly (which means a $25-30 12V 90W laptop-style power brick works). Other versions require a full SFX PSU. **Check the listing for the specific SKU you're buying.** If the listing says "12V DC input" or "DC jack," you can skip the SFX PSU and use a 12V 90W adapter instead — saves $30-40 and reduces noise.

---

## Build Order

### Phase 1: Hardware assembly (~1 hour)

1. **Unbox and inventory.** Confirm all parts, no DOA components. Inspect for shipping damage.

2. **Install RAM into the motherboard.** SO-DIMM slot is on the back of the board. Click into place at 45° angle, push down until latches engage.

3. **Install CPU cooler (if using aftermarket).** Apply thermal paste if not pre-applied. Mount per cooler instructions. CWWK's included fan is adequate but louder.

4. **Mount motherboard in Jonsbo N3 case.** Standoffs should be pre-installed for mini-ITX. Drop the board in, screw down (typically 4-6 screws).

5. **Connect front panel connectors.** Power button, reset, LED, front USB. Diagram in the case manual. Easy to get wrong — match pins carefully.

6. **Install the 2.5" boot SSD.** Jonsbo N3 has a dedicated 2.5" mount, usually at the back of the motherboard tray. SATA data + SATA power cables.

7. **Install the 4× 4TB 3.5" drives into the hot-swap caddies.** Slide each drive into a caddy, screw it in (4 screws per side, or toolless caddies depending on case version). Slide caddies into the front bays until they click.

8. **Connect SATA data cables from motherboard to each 3.5" drive backplane.** The hot-swap backplane has SATA ports — usually 4 of them, labeled. Connect to the motherboard's SATA 0/1/2/3 ports (or however they're labeled). Order doesn't matter for ZFS, but keeping them consistent helps debugging later.

9. **Connect power.** SATA power to the backplane, 24-pin to motherboard, 4-pin CPU power if the board has it.

10. **Close up the case.** Don't fully button it up yet — first boot should be open so you can see/hear the POST.

### Phase 2: First boot + BIOS (~15 min)

1. **Connect HDMI monitor + USB keyboard.** Don't need a mouse; the BIOS is keyboard-driven.

2. **Power on.** You should see POST. If not, check RAM seating, 24-pin power, front panel connectors.

3. **Enter BIOS** (DEL or F2 usually). Configure:
   - **Boot order:** USB first (for installer), then the SATA SSD
   - **Wake on LAN:** enabled (optional but nice)
   - **SATA mode:** AHCI (default, don't change)
   - **Power on after power loss:** enabled (auto-restart after outage)
   - **Save and exit.**

4. **Power off.** Now you can button up the case.

### Phase 3: TrueNAS Scale install (~30 min)

1. **Download TrueNAS Scale ISO** from `https://truenas.com/download/`. Current version as of this doc: SCALE 24.10 (Electric Eel) or newer.

2. **Flash to USB stick** using Rufus or balenaEtcher. 8GB stick is enough.

3. **Boot from USB.** Plug into the NAS, power on, select boot from USB in BIOS boot menu (F12 or F11).

4. **TrueNAS installer:**
   - Install to the 128GB boot SSD (will show as `/dev/sda` or similar — be careful, don't pick one of the 4TB drives)
   - Set a root password
   - The installer will warn about wiping the boot drive — confirm
   - **Do NOT configure storage in the installer** — we'll do that via the web UI

5. **Boot into TrueNAS.** Should auto-reboot without the USB stick. You'll see a console URL like `http://192.168.1.x` — note the IP.

6. **Access the web UI from your Windows PC.** Open a browser to that IP, log in as root with the password you set.

### Phase 4: ZFS pool creation (web UI, ~15 min)

1. **Storage → Create Pool:**
   - Name: `backup-primary`
   - Topology: Mirror
   - Layout: 2-way mirror
   - Vdevs: 2× (pick the first 4TB drive, then the second)
   - **Use `/dev/disk/by-id/` paths** if shown — more stable than `/dev/sda` etc.
   - Click Create

2. **Repeat for `backup-replica`:**
   - Same setup, but use the other 2 drives

3. **Create datasets under each pool:**

```
backup-primary
  └── restic-repo         (for restic versioned backups)
  └── vzdump              (for raw vzdump output, optional)

backup-replica
  └── restic-mirror       (for cross-pool rsync target)
  └── personal
      ├── photos
      ├── projects
      └── media
  └── proxmox-storage
      ├── lxc-templates
      ├── isos
      └── scratch
  └── phone-sync
      ├── photos
      └── documents
```

Each dataset: right-click the parent pool → Add Dataset. Set compression to `lz4` on each.

### Phase 5: Users + SMB share (~10 min)

1. **Credentials → Local Users → Add:**
   - Username: `adam`
   - Full name: your name
   - Password: strong password (this is the Windows login)
   - Primary group: `builtin_users`
   - Auxiliary groups: `builtin_administrators` (so you can manage shares)
   - Home directory: leave default
   - **Samba auth: enable**

2. **Shares → Add → SMB:**
   - Path: `/mnt/backup-replica/personal`
   - Name: `Personal`
   - Enabled: yes
   - **Allow guest access: NO** (you want authentication)
   - ACL preset: select `Open` or set custom — for personal files, you want `adam` to have full control

3. **Test from Windows PC:** File Explorer → `\\<NAS-IP>\Personal` → enter credentials → should see the share.

### Phase 6: NFS export for Proxmox nodes (~10 min)

1. **Shares → Add → NFS:**
   - Path: `/mnt/backup-replica/proxmox-storage`
   - **Network:** `10.0.100.0/24` (your LAN)
   - **Read-only:** no (Proxmox needs to write)
   - **Maproot User:** `root`
   - **Maproot Group:** `wheel`
   - Enabled: yes

2. **Repeat for `/mnt/backup-replica/restic-mirror` if you want it NFS-accessible (probably not needed — the rsync happens on the NAS itself).**

3. **Test from Proxmox node shell:**
   ```bash
   showmount -e <NAS-IP>
   mount -t nfs <NAS-IP>:/mnt/backup-replica/proxmox-storage /mnt/nas-storage
   ls /mnt/nas-storage
   umount /mnt/nas-storage
   ```

### Phase 7: Syncthing setup (~15 min)

1. **Apps → Discover → Syncthing → Install:**
   - Storage: map `/mnt/backup-replica/phone-sync` to `/data` in the container
   - No need for special config — defaults work

2. **Get the Syncthing web UI URL** (Apps → Syncthing → Web Portal). Note the URL.

3. **Open Syncthing web UI on the NAS.** You'll see an empty device list.

4. **On your Samsung Galaxy S26 Ultra:**
   - Install Syncthing from F-Droid (recommended) or Play Store
   - Open the app, allow permissions (storage, photos, etc.)
   - Go to Settings → add the NAS as a remote device (use the Device ID from the NAS's Syncthing web UI)

5. **On the NAS Syncthing web UI:**
   - Add Folder: `phone-camera` → path `/data/photos`
   - Share with the phone device
   - On the phone, accept the share, point to your DCIM/Camera folder

6. **On your Windows PC:**
   - Install Syncthing Tray from Microsoft Store (or `choco install syncthingtray`)
   - Add the NAS as a remote device (same Device ID as above, or use a different ID per device)
   - On the NAS, share `/data/photos` with the Windows device
   - On Windows, accept the share, point it to `C:\Users\Adam\Syncthing\photos` (or wherever)

Now everything syncs: phone → NAS → Windows PC.

### Phase 8: restic for Proxmox backups (~30 min)

1. **On the NAS — install restic.** TrueNAS Scale is Debian-based, so:
   - Open Shell (System Settings → Shell)
   - `apt update && apt install restic` (may need to enable a community repo for non-FreeBSD packages — TrueNAS Scale's app catalog is the easier route, but `apt` works for CLI tools)

2. **Initialize the restic repo:**
   ```bash
   restic -r /mnt/backup-primary/restic-repo init
   ```
   Save the password somewhere safe (1Password, a sealed envelope in a safe, etc.). **If you lose the password, the backups are unreadable.**

3. **Set up a daily backup script** (System Settings → Advanced → Init/Shutdown Scripts → Add):
   - Type: Script
   - Script contents:
   ```bash
   #!/bin/bash
   set -e
   REPO=/mnt/backup-primary/restic-repo
   export RESTIC_PASSWORD_FILE=/root/.restic-password
   # Add the Proxmox nodes' NFS exports as backup sources
   restic -r $REPO backup /mnt/backup-primary/vzdump
   restic -r $REPO forget \
     --keep-daily 7 \
     --keep-weekly 4 \
     --keep-monthly 3 \
     --prune
   ```
   - When: Daily, 2:00 AM
   - Enabled: yes

4. **Set up weekly restic check** (separate cron):
   - Type: Script
   - Script:
   ```bash
   #!/bin/bash
   restic -r /mnt/backup-primary/restic-repo check
   ```
   - When: Weekly, Sunday 3:00 AM

### Phase 9: Cross-pool replication (~10 min)

**In TrueNAS web UI:**

1. **Data Protection → Replication Tasks → Add:**
   - Source: `backup-primary` (or specific datasets)
   - Destination: `backup-replica`
   - Recursive: yes
   - Schedule: Hourly (TrueNAS uses ZFS send/receive under the hood, which is incremental and fast)
   - Enabled: yes

TrueNAS handles the ZFS snapshots and send/receive automatically. You get versioned, incremental, cross-pool replication with no scripting required.

**This replaces the nightly rsync I mentioned earlier** — ZFS send/receive is more efficient than rsync for this use case, and TrueNAS integrates it natively.

### Phase 10: Proxmox-side storage config (~5 min per node)

**On each Proxmox node, in the web UI:**

1. **Datacenter → Storage → Add → NFS:**
   - ID: `nas-storage`
   - Server: `<NAS-IP>`
   - Export: `/mnt/backup-replica/proxmox-storage`
   - Content: `Disk image`, `ISO image`, `Container`, `Templates`
   - Enabled: yes
   - **Read-only: no** (you want to write to it)

2. **Verify:** Datacenter → Storage should show `nas-storage` with the right content types and enough free space.

### Phase 11: Proxmox backup schedule (~5 min per node)

**In each Proxmox node's web UI:**

1. **Datacenter → Backup → Add:**
   - Storage: `Local` (or a new NFS target if you want backups to land on the NAS directly — that would be `backup-primary` via NFS, but we'd need to set up a second NFS share for it)
   - Schedule: Daily, 02:00
   - Selection: All VMs (or specific ones)
   - Mode: Snapshot
   - Compression: ZSTD
   - Notification: enable and point to... actually, Proxmox's built-in notification is email-based, which doesn't work for us. Skip for now and rely on the NAS-side monitor.

2. **Note:** vzdump creates files in the format `dump-vzdump-lxc-101-2025_06_02-02_00_00.tar.zst` in the configured backup directory.

3. **Optional:** have vzdump write directly to the NAS's `backup-primary` pool. This requires mounting that NFS share on the Proxmox node too, but it removes the "backup to local, then copy to NAS" intermediate step. Tradeoff: backups are slower (network vs local disk), but you don't have a local backup that's not protected by ZFS.

**My recommendation: back up to local, then have restic on the NAS pull the local backup files.** Two-hop, but each hop is simple and debuggable.

### Phase 12: Matrix alert integration (~20 min)

The UniFi monitor script you already have can be adapted. New script: `backup-monitor.sh` on Felix.

**Pseudo-code:**

```bash
#!/bin/bash
# Check if a fresh backup landed in the last 26 hours
LATEST=$(ls -t /mnt/backup-primary/vzdump/ 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
  hermes send --to "matrix:!ksqJXQgJ-jAmxwatiHw2ewX9flvdver1wMUABTCYFPo" \
    "🚨 NAS backup monitor: no backups found on backup-primary"
  exit 1
fi
AGE_HOURS=$(( ($(date +%s) - $(stat -c %Y /mnt/backup-primary/vzdump/$LATEST)) / 3600 ))
if [ $AGE_HOURS -gt 26 ]; then
  hermes send --to "matrix:!ksqJXQgJ-jAmxwatiHw2ewX9flvdver1wMUABTCYFPo" \
    "🚨 NAS backup monitor: latest backup is $AGE_HOURS hours old"
  exit 1
fi
echo "Latest backup: $AGE_HOURS hours old (OK)"
```

**Cron entry on Felix:** every 6 hours, run the script.

**This requires the NAS to export `backup-primary` over NFS too, or the script runs on the NAS itself.** Simpler: have the script run on Felix, and have Felix mount the NFS share from the NAS. We did this pattern for `backup-replica` already; we can add a second mount for `backup-primary` (or just make `backup-primary` available over the same NFS share structure).

---

## Summary

**After all 12 phases, you have:**

- ✅ A 4-drive NAS with 2× 4TB mirrored pools
- ✅ Pool 1: versioned Proxmox backups (restic), replicated to Pool 2
- ✅ Pool 2: personal files (SMB to Windows), Proxmox node storage (NFS), phone sync (Syncthing)
- ✅ Cross-pool replication via ZFS send/receive (built into TrueNAS)
- ✅ Matrix alerts when backups go stale
- ✅ Phone backing up automatically over LAN
- ✅ Samsung Galaxy S26 Ultra, Windows PC, and both Proxmox nodes all using the NAS

**What you don't get with this build:**

- ❌ Offsite backup (you explicitly didn't want cloud). Mitigation: monthly external USB drive rotation of the restic repo.
- ❌ Cross-pool replication of the personal storage pool (only backups are replicated).
- ❌ Real-time replication to a second location.

**Next steps:**

1. Order the parts (~$330-535 depending on choices)
2. While waiting, finish the SSH access setup to the Proxmox nodes (we were mid-thread on this)
3. When parts arrive, follow phases 1-12 in order
4. After first successful backup, test a restore (this is the part most people skip, then regret)

---

## Open questions / decisions deferred

- **External USB rotation schedule** — when (weekly? monthly?), where does the drive live, who rotates it
- **Whether vzdump should write to NAS directly or to local first then sync to NAS** — current doc does local-first, restic on NAS pulls. Alternative: vzdump writes to NAS-mounted NFS share. Simpler but slower.
- **TrueNAS app catalog vs apt for restic** — if you go app catalog, there's a restic app with a UI. If you go apt, command-line only. Both work; app is more "TrueNAS native."
- **Restic repository location** — currently `/mnt/backup-primary/restic-repo`. If you want it on a different dataset (e.g., separated from vzdump output for cleaner organization), easy to change.
- **How to back up the NAS itself** — if the NAS drive dies, the restic repo is gone. ZFS mirror handles single-drive failure, but a 2-drive failure in the same pool kills the repo. Mitigation: external USB rotation. Without it, you're trusting the mirror.

---
