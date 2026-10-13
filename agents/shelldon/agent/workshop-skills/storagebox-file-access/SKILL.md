---
name: storagebox-file-access
description: "Storage Box files, Nextcloud Documents via local CIFS mounts, or rclone `storagebox:` remote: inspect, compare, or stage a safe transfer."
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

   **Nextcloud user files:** the user names them Windows-style
   (`\Documents\0_Privat\<file>`). Translate backslashes to slashes and read
   via `/mnt/nextcloud/Documents/...` first (native CIFS mount; verified
   2026-10-09 for `Documents/0_Privat/20261009_140326_YOUTUBE-PUSH-FIX.md`).
   The same bytes also appear under
   `/mnt/storagebox-node/nextcloud/data/henning/files/Documents/...`, but prefer
   the shorter mount. Prove with `findmnt -T /mnt/nextcloud/Documents` plus a
   targeted `ls` of the named file — never via tool-catalog search (no Nextcloud
   file tool exists) and never via a recursive walk of `0_Privat/` (thousands of
   entries over CIFS).

   **Direct writes into the data tree need step 6's rescan** — a copy under
   `nextcloud/data/<user>/files/...` exists on disk but stays unlisted in
   the UI until scanned. See step 6.

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

6. **Rescan Nextcloud after writing directly into its data tree.** Files
   created under `/mnt/storagebox-node/nextcloud/data/<user>/files/...`
   land in Nextcloud's backend but stay invisible in the Nextcloud UI until
   `occ files:scan` registers them (observed: byte-identical files present
   on disk, absent from the UI). Trigger it through the `nextcloud-app`
   container on the gateway host:
   `docker exec -u www-data nextcloud-app php occ files:scan
   --path="<user>/files/<subpath>"` (user here is `henning`; scope
   `--path` to the changed folder, never a full scan). Local `docker` needs
   sudo on this host; prove the allowlist first (`sudo -n -l` — observed:
   only `docker ps *`, no `docker exec`) — when exec is denied, hand the
   owner that exact one-liner
   instead of hunting for another route. The owner's
   recurring scan job also picks up stragglers within minutes. Paths are
   case-sensitive: `ls -d .../*attern*` first, or a new lowercase folder
   duplicates an existing capitalized one (observed `greendex` vs
   `Greendex`). Finish when the UI (or a follow-up scan window) shows the
   files.

Verification: the chosen local mount or rclone remote produced a live listing;
all mutations had a reviewed dry-run and explicit approval; the destination was
re-read after an authorized change and any deletion confirmed on the `storagebox:`
view; no rclone configuration, key, or credential value appeared in output.
