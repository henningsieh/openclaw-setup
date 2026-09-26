---
name: photo-environments
description: Inspect or operate the Google Photos Takeout, Immich, and Storage Box photo workflow. Use for photo inventories, migration staging, duplicate checks, or the configured `storagebox` rclone remote; not for direct Google account access without an owner-supplied method.
---

# Photo environments

Read [`docs/runbooks/photo-environments.md`](../../../docs/runbooks/photo-environments.md)
before operating on personal photos. It is the authority for the environment
map, access paths, and capacity constraints.

For Immich health/API access, Takeout import retries, exports or stacks, use the
`immich-operations` skill and read the runbook's linked Immich operations
reference. The dedicated wiki entity is `entities/immich.md`; keep instance
facts there and storage boundaries in the environment runbook.

## Select the boundary

- **Google Photos** means the external upstream. The bulk migration is largely
  complete; current work is retry resolution and cleanup preparation. There is
  no configured account CLI or rclone remote. Use the Takeout source unless the
  owner supplies an access method.
- **Takeout source:** `/mnt/storagebox-node/Google-Fotos`; preserve JSON
  sidecars with their media.
- **Retry queue:** `/mnt/storagebox-node/Google-Fotos-retry`; establish whether
  a file is already in Immich before retrying it.
- **Immich:** import only with a supported CLI/API or the established importer.
  The Storage Box directory `/mnt/storagebox-node/immich` is production data,
  not a staging directory.
- **Storage Box:** use the local CIFS mount for ordinary reads. `rclone` remote
  `storagebox:` is SFTP and belongs to `shelldon`; never display its config or
  key.

## Work safely

1. Confirm the selected source and target, then perform the smallest useful
   read-only inspection (`rclone lsd`, `rclone size`, `find`, or `rclone check`).
2. Before a transfer, state the exact paths, execute the chosen rclone command
   with `--dry-run`, and report the result.
3. Obtain explicit owner approval before removing `--dry-run` or using any
   operation that writes, moves, deletes, syncs, purges, or uploads assets.
4. After an approved operation, verify the destination and report item counts,
   metadata-sidecar handling, and any failures.

## Google Photos cleanup

Treat a cloud deletion as its own approval gate. First establish that each
candidate is present in Immich with the intended metadata, produce a
human-reviewable candidate set, then obtain a fresh explicit owner approval
immediately before deletion. Do not delete local Takeout or Immich copies as
part of Google cloud-space cleanup.

## Constraints

- The host root disk is too small to hold a local Takeout mirror; stream or
  operate in place on the Storage Box.
- `rclone sync`, `move`, `delete`, and `purge` are destructive in this context.
- Do not use `/mnt/storagebox`: it is mapped to `www-data`, not `shelldon`.
