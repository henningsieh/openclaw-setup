---
name: "disk-space-reclamation"
description: "Free root-disk space without data loss: measure, rank candidates by safety, verify nothing is in use, delete regenerable/temp/superseded files directly, keep databases and rollback material."
---

# Disk Space Reclamation

Use when the host disk is filling and the owner wants space back without losing
data. This is host housekeeping; it is not backup-destination retention
(`backup-retention-policy`) and not an ENOSPC fault during a memory repair
(`repair-memory/references/disk-pressure-recovery.md`) — read those when the
trigger is a backup folder or a gateway fault instead.

1. **Measure before deleting anything.** `df -h /` for the headline number and
   `df -i /` for inodes, then rank the big trees with bounded depth
   (`du -xsh <dir>/*` two or three levels deep, never a bare `du /`). Record the
   before number so the gain is provable. Finish when the top GiB-consumers are
   named with sizes.

2. **Sort candidates into safety classes, delete the safe ones first.**
   - **Regenerable** — HTTP/build caches (`~/.npm/_cacache`, compile caches,
     Playwright/browser caches). Rebuilt on demand; no data lost.
   - **Temp copies** — `/tmp/*.sqlite` and `/tmp/<dir>/openclaw-*.sqlite` are
     database *copies* made by diagnostics, not the originals; these can reach
     GB scale and are pure leftovers once idle.
   - **Superseded** — migration `.bak` snapshots and update rollback captures
     (`~/.openclaw.update-captures`), once the version they guard is accepted.
   - **Trash** — `~/.local/share/Trash`, `~/.Trash`.
   Never touch: live databases and their `-wal`/`-shm`, active model files, the
   running install, or any path still in use (step 3). Finish when each candidate
   has a named class and the unsafe set is explicitly excluded.

3. **Prove a candidate is idle before deleting it.** `lsof +D <path>` — zero lines
   means no process holds it. A cache the gateway, Codex, or a running job has
   open must not be removed mid-run; that breaks the live process. Never delete on
   size alone. Finish when every path you intend to remove returns an empty handle
   list.

4. **Delete directly, not to Trash.** Moving a file to Trash on the *same*
   partition frees **zero** bytes — the data still occupies the disk until the
   trash is emptied. Use `rm -rf` for regenerable/temp/superseded items. Reserve
   `gio trash` for a file on a *different* volume where recoverability is wanted
   and freeing space is not the goal.

5. **Confirm originals and the gain.** Re-run `df -h /`, state before → after, and
   spot-check that live data survived (`ls -l` the agent/state SQLites). Finish
   when the freed amount is stated and the live files are shown intact.

6. **Hand off root-only items instead of attempting them.** `apt clean` (~100 MB)
   and `journalctl --vacuum-size=<n>` need elevation the agent usually lacks; name
   them as operator actions with their size, do not try to run them.

Verification: before/after `df -h /` recorded; every deleted path had a named
safety class and an empty `lsof` result; live databases and the rollback material
for the accepted version were left in place; Trash was not used as the freed-space
path; root-only candidates were reported, not run.
