# NAS — Asustor Drivestor 4 Gen2 (AS1204T)

A 4-bay NAS used as a Proxmox backup target + network storage extension + phone backup hub + personal file share.

**Hardware:** Asustor AS1204T (4-bay, Realtek RTD1619B quad-core, 1GB DDR4, 2.5GbE) + 4× 4TB 3.5" drives.

**Cost:** ~$285 (NAS unit only — drives are reused spares).

**See [`setup-guide.md`](setup-guide.md) for the full setup walkthrough** — covers ADM setup, Btrfs volume creation, SMB + NFS + Syncthing + restic + Proxmox integration + Matrix alerts.

## At a glance

- **Topology:** 2× 2-drive Btrfs RAID1 mirrors (4TB usable each)
- **Volume 1 (backup-primary):** Proxmox vzdump + restic versioned snapshots, copied nightly to Volume 2
- **Volume 2 (backup-replica):** personal files (SMB), Proxmox node storage (NFS), phone sync (Syncthing), and a restic copy of Volume 1
- **Status:** Ready to order. Setup guide covers unboxing through post-build integration.
- **Build cost:** ~$285 (NAS only — drives are free)
