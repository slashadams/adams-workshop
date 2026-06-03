# NAS — Asustor Drivestor 4 Pro Gen2 (AS3304T v2)

A 4-bay NAS used as a Proxmox backup target + network storage extension + phone backup hub + personal file share.

**Hardware:** Asustor AS3304T v2 (Drivestor 4 Pro Gen2) — 4-bay, Realtek RTD1619B quad-core, 2GB DDR4 (soldered, non-upgradeable), 2.5GbE + 4× 4TB 3.5" drives.

**Cost:** ~$340-380 (NAS unit only — drives are reused spares). Same price at Amazon and B&H Photo, both with free shipping; Amazon typically arrives faster.

**See [`setup-guide.md`](setup-guide.md) for the full setup walkthrough** — covers ADM setup, Btrfs volume creation, SMB + NFS + Syncthing + restic + Proxmox integration + Matrix alerts.

## At a glance

- **Topology:** 2× 2-drive Btrfs RAID1 mirrors (4TB usable each)
- **Volume 1 (backup-primary):** Proxmox vzdump + restic versioned snapshots, copied nightly to Volume 2
- **Volume 2 (backup-replica):** personal files (SMB), Proxmox node storage (NFS), phone sync (Syncthing), and a restic copy of Volume 1
- **Status:** Ready to order. Setup guide covers unboxing through post-build integration.
