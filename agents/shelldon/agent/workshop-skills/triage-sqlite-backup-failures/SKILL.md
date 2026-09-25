---
name: "triage-sqlite-backup-failures"
description: "An OpenClaw backup or backup automation fails with ERR_SQLITE_ERROR, 'cannot be compacted safely', 'not an error', or a related capture/publication error: prove the state data is healthy on private WAL-complete copies, bisect the current source, and separate snapshot, archive-walker, permission, and lock failures."
---

# Triage SQLite Backup Failures

Use when `openclaw backup create` (manual or scheduled) fails during state capture, compaction, archive walking, or publication. The top-level message is often a wrapper summary; it is not proof of corruption and it is not necessarily the first failing step.

## Safety invariants

- Never write, compact, checkpoint, delete, rename, or change ownership/mode of the live `openclaw.sqlite`, `-wal`, or `-shm` files. All mutating SQLite work belongs in a private copy.
- Do not run the external `sqlite3` CLI against the active state directory. Its policy refusal is a guard, not evidence of corruption. Use OpenClaw's sanctioned commands or Node's built-in `node:sqlite` on a private copy.
- Serialize probes and backup attempts. A still-running probe, abandoned backup scratch, or several concurrent workers can create the lock/CPU pressure being investigated. A live comparison, if explicitly needed, is read-only and never uses a writable handle.

1. **Establish the release and failure phase.** Read the cron receipt (`openclaw cron runs <jobId>`) and command output. In the gateway log for the run's date, capture the exact path, timestamp, and nearby `SQLite read-only snapshot`, `SQLite snapshot operation completed`, `Backup archive`, verification, `EACCES`, and `database is locked` lines. Run `openclaw --version` and inspect the installed package version before trusting handoff filenames or hashes. Classify the first visible boundary as **snapshot/capture** (no tar publication yet), **archive walk/publication** (a named file, permission, scratch, or publication error), or **source/coordination** (snapshot retry or source lock). A later success line does not prove the whole backup succeeded. Finish with the phase, path, and timestamps named.

2. **Verify a WAL-complete private copy.** Copy `openclaw.sqlite`, `openclaw.sqlite-wal`, and `openclaw.sqlite-shm` together into a private `0700` directory outside the state directory; do not copy only the main file. Use Node's built-in SQLite and keep writes in the copy:

   ```bash
   node --input-type=module - <<'NODE'
   import { DatabaseSync } from "node:sqlite";
   const db = new DatabaseSync("/tmp/private/src.sqlite", { readOnly: false, allowExtension: true });
   console.log(db.prepare("PRAGMA integrity_check;").get());
   db.exec("PRAGMA journal_mode=WAL; VACUUM;");
   console.log(db.prepare("PRAGMA integrity_check;").get());
   db.close();
   NODE
   ```

   Two `integrity_check: ok` results and a successful compaction establish a healthy private snapshot. If the copy itself is inconsistent, reacquire the complete file set; never repair the source to make the test pass. Finish with an explicit healthy/copy-invalid verdict.

3. **Map the current minified exports before writing a harness.** Hashed filenames and one-letter exports change between releases. Read the current `dist/backup-create-*.mjs`, `dist/sqlite-snapshot-*.mjs`, sanitizer, registry, legacy-audit, and cold-storage modules, then import their actual aliases (for example, `t` may be `createVerifiedSqliteSnapshot` and `D` may be `assertOpenClawStateDatabaseOwner`). A harness that reports `createVerifiedSqliteSnapshot is not a function` tested nothing; fix the harness before drawing conclusions.

4. **Bisect the real callback chain on fresh private inputs.** Import the current implementations of owner validation, agent-registry reads, the global sanitizer, legacy-audit witness/checkpoint helpers, and cold-archive embedding. Run a fresh private copy for each boundary: baseline, owner validation, registry read, legacy witness, legacy checkpoint rewrite, sanitizer, cold-archive embed, and the full combined transform. Name `PASS`/`FAIL` for every step and preserve the first thrown error chain. On the global database, a missing `session_transcript_cold_archives` table makes the cold-archive branch a valid no-op, not a failure. If all real callbacks pass, stop blaming them and move to the source/archiver boundary; do not keep deleting or “fixing” rows to make a callback test pass.

5. **Separate the sanctioned snapshot boundary from the archive wrapper.** Replay the real snapshot primitive on the private copy: integrity check, extension load, online `node:sqlite` backup, rollback, staged `journal_mode=DELETE`, `VACUUM`, and a second integrity check. Use `openclaw backup create --dry-run --json` for discovery only and `--only-config --verify` as a config/archive bracket; neither proves state capture. If the private state plan passes but the normal command still fails, make a private overlay of the installed `dist` (symlink dependencies, copy only the target backup module, expose its internal state-plan function) and run that function into a temporary directory. A passing state-plan run narrows the fault to archive walking/publication or a post-plan wrapper. Capture the full `cause` chain from a direct harness rather than accepting the CLI's flattened message.

6. **Branch on permission and lock errors without conflating them with SQLite.** An `EACCES` naming a config/backup file is an archive-walker/permission failure: inspect that exact file with `stat`; if it is demonstrably stale/recoverable and operator policy permits it, move it reversibly to Trash (for example, `gio trash`) and rerun. Never apply this to a database, WAL, SHM, or active scratch directory. `database is locked` while retiring `openclaw-backup-owned-*` is a scratch/cleanup or concurrent-probe problem: stop temporary probes, inspect ownership and open handles, and preserve scratch until it is provably abandoned. Do not force-remove a lock. Rule out destination space (`df -h / /mnt/openclaw-backup`) and remember that a multi-MB WAL beside a busy gateway is normal, but do not mistake either for the source of this wrapper error.

7. **Require a green completion test before declaring a fix.** A repaired backup requires all of: the real official `backup create --output <destination> --verify` exits 0 and prints an archive path; `openclaw backup verify <archive>` succeeds; and a forced `openclaw cron run <jobId> --wait --expect-final` (or the next scheduled receipt) is `ok`. A config-only archive, dry run, private snapshot, or direct state-plan pass is not enough. If no green full run is available, report the localized boundary and keep the gateway-side cause explicitly unresolved; do not edit the live database or claim a fix.

Verification: the current release and exact failure phase are recorded; the private WAL-complete copy has two clean integrity checks; every real callback has a named PASS/FAIL result; any live comparison was read-only; snapshot, archive-walker, permission, and lock findings are separated; and the full verified archive plus green cron receipt are required before success is reported.
