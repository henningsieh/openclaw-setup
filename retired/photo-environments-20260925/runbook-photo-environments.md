# Photo environments

This runbook maps the personal photo estate available to the `shelldon` user.
It is an operations reference, not a migration script.

For Immich API access, the installed `immich-go` client, import/export recipes,
and source-backed administration guidance, read
[Immich operations](immich-operations.md). The `immich-operations` skill handles
that branch; this runbook remains authoritative for environment boundaries.

## Roles and boundaries

| Environment | Role | Access from `shelldon` | Operating rule |
|---|---|---|---|
| Google Photos | Upstream photo service | No configured account CLI or rclone remote | Treat the current Google Takeout as the available source. Ask the owner for an access method before attempting direct account access. |
| Google Takeout | Migration evidence and retry source | `/mnt/storagebox-node/Google-Fotos` | The bulk migration is substantially complete. Preserve media files and JSON sidecars; use it to resolve outstanding retries and verify cloud-cleanup candidates. |
| Immich | Private production photo library | `https://immich.sieh.org`; Storage Box area at `/mnt/storagebox-node/immich` | Use Immich-supported CLI/API or the established importer. Never alter the production data directory directly. |
| Failed migration area | Small retry queue | `/mnt/storagebox-node/Google-Fotos-retry` | Inspect failures before retrying; avoid re-uploading assets already present in Immich. |
| Hetzner Storage Box | Shared storage substrate | CIFS mount and a `shelldon`-only SFTP rclone remote | Use the CIFS mount for ordinary local reads; use rclone when its remote copy/check semantics are useful. |

`_bak` and `nextcloud` on the Storage Box are outside the photo-migration
workflow.

## Verified access and capacity

- CIFS share: `//u558492.your-storagebox.de/backup`, mounted at
  `/mnt/storagebox-node` with `shelldon` ownership (UID/GID 1000), SMB 3.1.1,
  read/write access, and `serverino`.
- The same share is available as the SFTP rclone remote `storagebox:`. Its
  config is `/home/shelldon/.config/rclone/rclone.conf`; the key is outside the
  repository at `/home/shelldon/.ssh/storagebox_key`. Do not print, copy, or
  commit either credential material or rclone config contents.
- `rclone` is installed system-wide (verified version: `v1.60.1-DEV`).
- At the 2026-09-25 inventory, `Google-Fotos` held 48,649 objects / 45.928 GiB;
  the Storage Box had about 518 GiB free while the host root filesystem had
  about 5.2 GiB free. Do not mirror the Takeout onto the host root disk.

## Current completion plan

The bulk Google Photos → Immich migration is already substantially complete.
The remaining work has two ordered phases:

1. **Resolve `Google-Fotos-retry`.** Diagnose each failed item, determine
   whether it already exists in Immich, and retry only genuinely absent assets
   using an Immich-supported importer. Keep the retry queue as evidence until
   the result is verified.
2. **Prepare Google Photos cleanup.** The Google account was at 14.69 GB of 15
   GB (97%) on 2026-09-25. Build an owner-reviewable deletion set only after
   its assets and metadata have been verified in Immich. No Google Photos cloud
   deletion is currently configured or authorized from `shelldon`.

The cleanup goal is Google cloud-space reclamation, not deletion of the local
Takeout or Immich assets.

## Safe operating sequence

1. **Inspect first.** Confirm mounts/remotes with `findmnt` and `rclone lsd`;
   then scope an inventory to the named folder. Do not repeat full inventories
   unless their result is needed.
2. **Compare before transfer or deletion.** Use `rclone check` or an
   importer-supported duplicate check. Preserve Takeout JSON sidecars when the
   chosen importer can consume them. For a Google Photos cleanup candidate,
   prove the equivalent asset and intended metadata exist in Immich first.
3. **Stage only deliberately.** For a copy or move, run the exact command with
   `--dry-run`, report its target and expected effect, and obtain explicit owner
   approval before the real operation.
4. **Import through Immich.** Production imports happen through an
   Immich-supported CLI/API or the established migration process, never by
   writing into `/mnt/storagebox-node/immich`.
5. **Verify and report.** Record the command, source, destination, item count,
   and whether JSON metadata was retained. A failed subset belongs in
   `Google-Fotos-retry` only after it is confirmed not to be an existing Immich
   asset.

Google Photos deletion is a separate, destructive external action. It requires
an owner-supplied account-access method, an explicit reviewed deletion set, and
fresh owner approval immediately before the action.

## rclone reference

Run as `shelldon`; do not use root's home or another user's configuration.

```bash
# Connectivity and top-level view (read-only)
rclone lsd storagebox:
rclone lsd storagebox:Google-Fotos

# Narrow, read-only size inspection
rclone size storagebox:Google-Fotos-retry

# Compare one scoped album without copying; name the comparison basis in the run log.
rclone check "/mnt/storagebox-node/Google-Fotos/<album>" "storagebox:Google-Fotos/<album>" --one-way

# Preview a copy. Remove --dry-run only after explicit owner approval.
rclone copy /mnt/storagebox-node/Google-Fotos-retry storagebox:Google-Fotos-retry --dry-run --progress
```

`rclone sync`, `delete`, `purge`, `move`, or an unreviewed `copy` are remote
mutations. Name one explicit source and target, dry-run first, and wait for the
owner's approval.
