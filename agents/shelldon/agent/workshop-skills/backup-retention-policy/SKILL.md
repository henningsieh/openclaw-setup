---
name: backup-retention-policy
description: A backup folder grows without bound or a retention is requested: measure growth, choose a windowed keep rule, put the prune in the job, prove steady state.
---

# Backup Retention Policy

Use when a backup destination accumulates archives with nothing pruning them, or
when asked to set, change, or review a retention rule. Reach for the read/write
paths in `storagebox-file-access` for the mount itself, and
`triage-sqlite-backup-failures` when a backup run is *failing* rather than piling
up. This skill owns the policy: what to keep, and who removes it.

1. **Establish that no built-in knob already does this.** `openclaw backup create`
   exposes no keep/retention/expire flag on any release so far — check
   `openclaw backup create --help` and the docs page before designing around a
   prune. When nothing exists, the prune belongs in the job that writes the
   archive, never in a hand-run sweep, or it stops matching the write pattern the
   moment the job changes. Finish when the prune target is the job's own payload,
   not a manual command.

2. **Measure the trend before choosing any count.** Count the archives, total
   bytes, per-period size, and the age of the newest one; note days that hold more
   than one archive. A fixed file count is not a bound when the payload itself
   grows — here 0.6 GiB in June became 2.5 GiB by late August, so 123 daily files
   held 168 GiB and a "keep 30" rule would still have drifted upward. Judge a
   candidate window by *steady-state bytes* (`archives kept × current average`),
   not by file count. Finish when the per-period size trend and the projected
   steady state are both stated.

3. **Pick a windowed keep rule, not a single number.** Daily + weekly + monthly
   tiers bound both recovery granularity and total size while the payload keeps
   growing. Default `14 / 8 / 6` suits a nightly job; tighten or loosen from the
   measured payload. Anchor the windows on the **newest archive's day**, not on
   wall-clock time: a destination whose newest archive is 30 days old must not
   have its whole history judged stale in one pass. Finish when the window and
   its anchor are written down.

4. **Produce the plan with a repeatable script, never by hand.**
   `scripts/retention_plan.py` implements step 3 as a read-only plan and, only
   under `--apply`, as the deletion:

   ```bash
   python3 scripts/retention_plan.py --dir /mnt/openclaw-backup
   python3 scripts/retention_plan.py --dir <dest> --daily 14 --weekly 8 --monthly 6 --json
   python3 scripts/retention_plan.py --dir <dest> --apply   # only after owner approval
   ```

   It keeps the newest archive of each retained day, reports the days it dropped
   a same-day duplicate from, and **never touches a file it cannot classify** —
   that refusal is what protects scratch directories and sidecar files sitting in
   the same folder. Report the plan's keep/delete counts and GiB to the owner and
   get explicit approval before `--apply`; a plan run that reports `PLAN
   (read-only)` has deleted nothing. Finish when the owner has approved a named
   plan or the work stayed read-only.

5. **When the destination is synced, say what a delete does to other devices.**
   Deleting inside a Nextcloud-synced folder propagates to the server and every
   client. That is the correct way to prune, but it must be an owner decision with
   that consequence stated, not a surprise.

6. **If the trend still looks wrong, profile the payload before widening the
   window.** Read one archive's own manifest to see what it claims, then aggregate
   the payload to see what actually fills it:

   ```bash
   # 1. the archive's own claim (anchor the exact archive root)
   tar -xzOf <newest>.tar.gz <archiveRoot>/manifest.json

   # 2. what actually fills it, aggregated by BYTES (not file counts)
   python3 -c "
   import tarfile, collections
   a = collections.Counter(); t = tarfile.open('<newest>.tar.gz', 'r|gz')
   for m in t:
       if not m.isfile(): continue
       p = m.name.split('/')
       k = '/'.join(p[p.index('.openclaw') + 1:]).split('/')[0] if '.openclaw' in p else '<other>'
       a[k] += m.size
   for k, v in a.most_common(6): print(f'{v/2**30:7.3f} GiB {100*v/sum(a.values()):5.1f}%  {k}')
   "
   ```

   Three traps: `tar -xzOf --wildcards "*/manifest.json"` silently prints every
   plugin and browser-extension manifest before the backup's own, so anchor the
   exact archive root; a member path is only splittable at `.openclaw` when the run
   is rooted there, so keep the `<other>` bucket and read it before trusting the
   ranking; and aggregate `m.size`, not a file count — a count-ranked profile can
   name a directory of many tiny files over the one holding the bytes. Here
   `plugins/` was 56 %, `agents/` 19 % and `models/` 19 % of an archive, all
   regenerable trees, which is a payload decision (`--no-include-workspace`, a
   tighter config) and not something retention can fix. Finish when the driver of
   growth is named, even if the policy work is done.

7. **Install the prune where the archive is created, then prove it.** For an
   OpenClaw automation this is the job's own `command` payload — read it with
   `openclaw automations get <id> --json` and keep the existing
   `backup create --output <dir> --verify` step intact, adding the prune after a
   successful run. Re-run the planner after a real backup and confirm the
   destination holds only the planned survivors, then report the resulting size
   and the next scheduled run. Finish when the job itself reports the prune, not
   a manual run.

**Anti-patterns:** a bare `find <dir> -mtime +30 -delete` over a folder that also
holds scratch directories and sidecars; a `keep last N files` rule presented as a
size bound; counting archives without measuring the payload trend; and hand-writing
a fresh one-off prune script when `scripts/retention_plan.py` already produces the
plan, because the second script is the one nobody re-runs after a format change.

Verification: the retention knob was checked against the installed CLI and the
prune lives in the writing job; the size trend and steady-state projection are
stated; the plan was produced by `scripts/retention_plan.py` in read-only mode and
the keep/delete counts and GiB were reported; any deletion had explicit owner
approval with the sync consequence stated; unclassified entries were preserved; and
the post-change destination was re-listed rather than assumed.
