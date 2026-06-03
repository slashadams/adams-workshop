# NAS Build

A 4-drive NAS built around a Jonsbo N3 case and a CWWK N100 board, running TrueNAS Scale.

**Purpose:** backup target for two Proxmox nodes + network storage extension + Syncthing hub for phone + SMB share for personal files.

**See [`build-and-setup.md`](build-and-setup.md) for the full build doc.**

## At a glance

- **Topology:** 2× 2-drive ZFS mirrors, with cross-pool replication for backups
- **Pool 1 (backup-primary):** Proxmox vzdump + restic versioned snapshots
- **Pool 2 (backup-replica):** personal files, Proxmox node storage, Syncthing receive folder, and a ZFS-replicated copy of Pool 1
- **Build cost:** ~$330-535 new (parts only — your 4× 4TB drives are the data tier), depending on where you source the board/case
- **Status:** Parts list ready, awaiting order. Doc covers assembly through post-build integration.
