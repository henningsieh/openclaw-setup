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

1. **Try the native retention before designing anything.** `openclaw backup create`
   has no keep flag, but every archive command that targets a storage location
   accepts `--keep-daily`, `--keep-weekly`, and `--keep-monthly`, and the Gateway
   schedule wraps them:

   ```bash
   openclaw storage list        # no locations configured => retention cannot run
   openclaw backup enable --to <location> --every 24h --keep-daily 7 --keep-weekly 4 --keep-monthly 12
   ```

   A `filesystem` location is `provider: "filesystem"` plus
   `settings: { path: "/absolute/existing/dir" }` in `storage.locations.<name>`;
   a CIFS or bind-mounted directory works. Set `encryption` in the same entry
   every time — `"none"` for plaintext, or an object carrying the passphrase —
   because leaving it out fails schema validation with
   `storage.locations.<name>.encryption: Invalid input`, which reads like a bad
   value rather than a missing key. Write the location through a validated patch
   rather than editing JSON by hand:

   ```bash
   cp -a ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak-$(date +%Y%m%d%H%M%S)
   printf '%s\n' '{ storage: { locations: { backup: { provider: "filesystem", encryption: "none", settings: { path: "/mnt/openclaw-backup" } } } } }' \
     | openclaw config patch --stdin --dry-run   # then rerun without --dry-run
   openclaw config validate                     # must print Config valid
   openclaw storage init <name>                 # "no initialization marker" is the expected pre-state
   openclaw storage test <name>                 # must report wrote, read, verified, deleted
   openclaw storage list                        # must report ok, not just the path
   ```

   Retention keeps the newest archive of each selected UTC day, week, and
   month, always keeps the newest archive, and runs only after a successful
   upload; without any `--keep-*` flag nothing is ever pruned. `backup enable`
   anchors its interval at creation time and has no option to pick a clock hour,
   so the job lands at "now + interval". Verify what was actually provisioned
   with `openclaw automations get <id> --json` and read `payload.argv`: the
   namespace (default: sanitized hostname) and the `--keep-*` numbers live there,
   not in the enable command's output. A `storage` config change only takes
   effect after a Gateway restart, which the Gateway defers while work is
   running; until then the schedule resolves the old in-memory config, so report
   the restart as pending instead of claiming the job is already live. The restart is an in-process
   `SIGUSR2` reload, so the PID does not change and only the journal proves it
   happened: `received SIGUSR2; restarting`, then `[gateway] ready`, then
   `openclaw storage list` reporting ok. The Gateway runs as a system-scope unit,
   so restarting it needs `sudo systemctl restart openclaw-gateway`; an
   unprivileged `systemctl restart` stops at a polkit password prompt. Finish
   when native retention is either enabled with the flags visible in the
   automation payload, or ruled out with a stated reason (usually no location and
   the owner declined one) — only then fall through to a custom prune.

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

4. **When native retention is unavailable, produce the plan with a repeatable
   script, never by hand.**
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

7. **Retire the old writer and prove steady state.** Enabling the Gateway schedule
   while a nightly automation still runs `backup create --output <dir>` leaves two
   writers on one destination; find it with `openclaw automations list --all` and
   disable that job in the same change. When the owner defers that step, state the
   running cost in the report — two full archive uploads per night — rather than
   leaving it unmentioned. Native
   retention only deletes keys matching its own archive filename pattern inside
   `backups/<namespace>/`, so pre-existing loose tarballs in the location root
   survive forever — list them, show the owner what a one-time cut would keep, and
   prune them separately once approved. When step 1 was ruled out, put the prune in
   the job that writes the archive: read its payload with
   `openclaw automations get <id> --json`, keep the existing `backup create` step,
   and add the prune after a successful run. Finish when a real backup has run and
   `openclaw backup list --from <location>` (or a fresh directory listing) shows exactly
   the planned survivors.

8. **Read the first real run's result, not the schedule.** A provisioned job is
   not a working job. Read `openclaw automations get <id>` and require
   `lastRunStatus: ok`; `error` with `consecutiveErrors ≥ 1` names the failure in
   `lastDiagnosticSummary`, and an empty destination next to a scheduled job is
   the same signal. The commonest first-run failure is scratch location: managed
   scratch is created under `TMPDIR`, and when `TMPDIR` sits inside the state
   directory publication is refused with `Backup output must not be written
   inside a source path: <tmp>/openclaw-backup-owned-*/archive.tar.gz is inside
   <state dir>`. Read the Gateway's own environment rather than your shell's with
   `tr '\0' '\n' < /proc/<gateway pid>/environ | grep -i tmp`; a systemd drop-in
   adding `Environment=TMPDIR=` is the usual cause. Then point scratch outside the
   state tree and re-run with `openclaw automations run <id>` until
   `lastRunStatus` is ok and `openclaw backup list --from <location>` lists an
   archive. Finish when one real run has succeeded end to end.

**Anti-patterns:** writing a custom prune when `openclaw backup enable --keep-*`
already covers the destination; `logrotate` over a backup directory (it renames
into `.1`, `.2` and gzips, so archives stop looking like archives) or
`systemd-tmpfiles --clean` (deletes by age across the whole directory, including
scratch and sidecars) presented as a retention mechanism; a bare
`find <dir> -mtime +30 -delete` over a folder that also holds scratch directories
and sidecars; a `keep last N files` rule presented as a size bound; counting
archives without measuring the payload trend; expecting native retention to
prune archives that already sit outside `backups/<namespace>/`; and reporting a
schedule as done before one run has succeeded.

Verification: the native retention knob was checked and used when a storage
location exists, or its absence is stated with the reason; `openclaw config
validate` passes, `openclaw storage list` reports the location as ok, and the
automation payload shows the intended `--keep-*` values and namespace; the job's
`lastRunStatus` is ok and the destination lists the archive it produced; no
second job writes the same destination; the size trend and steady-state projection are stated; any
plan came from `scripts/retention_plan.py` in read-only mode with keep/delete
counts and GiB reported; any deletion had explicit owner approval with the sync
consequence stated; unclassified entries were preserved; and the post-change
destination was re-listed rather than assumed.
