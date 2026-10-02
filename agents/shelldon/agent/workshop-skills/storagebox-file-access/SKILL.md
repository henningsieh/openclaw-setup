---
name: storagebox-file-access
description: "Storage Box files or rclone `storagebox:` remote: inspect, compare, or stage a safe transfer with the existing Shelldon credentials."
---

# Storage Box File Access

Use for files on the Hetzner Storage Box or the configured `storagebox:` rclone
remote. For application production data, follow that application's own documented
import or maintenance process. This skill owns reaching and changing the files;
use `backup-retention-policy` when the question is which of them to keep.

1. **Prove the access path before describing its capability.** Run `findmnt -T
   /mnt/storagebox-node` for the local share and `rclone lsd storagebox:` for
   the authenticated SFTP remote. An absent environment variable or SSH alias
   does not prove that rclone access is absent. Finish when each path needed by
   the task returns a live result.

2. **Choose the narrowest path for the work.** Use `/mnt/storagebox-node/...`
   for ordinary local reads and files already reachable through the CIFS mount.
   Use `storagebox:` when rclone's remote listing, `check`, or transfer behavior
   is the reason for the operation. Run as `shelldon`; the rclone config and
   SFTP key stay outside Git and are never displayed. Finish when the selected
   source and destination are explicit.

3. **Inspect or compare before any change.** Scope the smallest useful
   `rclone lsd`, `rclone size`, `rclone check`, or filesystem listing to the
   requested folder. Treat a successful listing or check as evidence of access,
   not of a completed transfer. If an inspection returns an unexpected empty
   result, error, timeout, or conflicts with the requested fact, stop and report
   the exact result to the owner. Do not silently substitute another mount,
   remote, command, or parsing method; use an alternate approach only after the
   owner explicitly asks for it or grants latitude to do so. Finish when item
   differences or the no-change result are known, or the exact blocker has been
   reported.

   **Keep content search shallow.** This share holds multi-gigabyte archives
   (`trash/` alone contained ~75 GB of takeout `.tgz` files), and a recursive
   content search such as `grep -r` over the mount walks those archives over
   CIFS and appears to hang. Search only the named files or the top-level
   directory, restrict by extension (`--include`), or run the same search against
   the `storagebox:` remote or a local copy. A command that has produced no
   output for a minute over this mount is usually scanning, not wedged — narrow
   it rather than waiting it out.

4. **Stage mutations visibly.** Name the exact source and destination, run the
   intended rclone operation with `--dry-run`, and report the expected effect.
   Obtain explicit owner approval before the real `copy`, `move`, `sync`,
   `delete`, or `purge`. Finish when the owner has approved the reviewed dry-run
   or the task remains read-only.

5. **Verify the authorized result, and confirm deletions on the authoritative
   view.** Re-list or check the named destination and report the resulting item
   count and any failures. For a deletion, judge the result with
   `rclone lsf storagebox: --dirs-only --max-depth 1` and `rclone size
   storagebox:<path>`: the CIFS mount can keep showing an **empty directory
   entry** with a deletion-pending marker for a short time after a successful
   remote delete, so a bare `ls /mnt/storagebox-node` can contradict the SFTP
   truth. Treat that as stale cache, not as a failed delete — re-check the
   remote rather than re-running the removal. Preserve `/mnt/storagebox` for its
   `www-data` consumer; Shelldon uses `/mnt/storagebox-node` instead. Finish when
   the requested destination state is observed on the remote.

Verification: the chosen local mount or rclone remote produced a live listing;
all mutations had a reviewed dry-run and explicit approval; the destination was
re-read after an authorized change and any deletion confirmed on the `storagebox:`
view; no rclone configuration, key, or credential value appeared in output.
