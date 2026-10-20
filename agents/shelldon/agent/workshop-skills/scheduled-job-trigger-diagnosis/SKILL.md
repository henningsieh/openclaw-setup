---
name: "scheduled-job-trigger-diagnosis"
description: "A scheduled/cron automation job didn't fire, is disabled, fired at the wrong time, is blocked by an archived session, or you need to know whether it failed in the past: read the enabled flag first, then separate job status from payload delivery, debug trigger-script gating, and reach run history older than the ring buffer."
---

# Scheduled Job Trigger Diagnosis

Use when the question is "why didn't my scheduled job run", "did it fire", or
"has it ever failed". Heartbeats are a special case — their gating and delivery
semantics live in `heartbeat-schedule-setup`; this skill covers the job row,
its trigger script, and its run history. Read-only diagnosis first; the job's own
payload script is the only thing you execute.

0. **Read `enabled` and its timestamp before anything else.** `openclaw automations
   get <jobId>` (or `cron get`) returns `enabled` plus `updatedAtMs`. A job that
   is `enabled: false` produces no runs at all — no trigger evaluation, no receipt,
   nothing in `cron runs` — so every deeper check is wasted until it is back on.
   Report the flag and when it changed in your first sentence; do not describe a
   disabled job as "not firing" and then hunt the trigger.

   The CLI verbs are `enable` / `disable` for the flag; there is **no `update`
   subcommand** and no `--enabled` flag:

   ```bash
   openclaw cron enable <jobId>     # openclaw cron disable <jobId>
   ```

   For any other field — schedule, `--description`, `--name`, per-job `--model` /
   `--thinking` — use **`openclaw cron edit <jobId>`** (patch semantics: only the
   flags you pass change). Verified: `--cron`, `--tz`, `--description` all exist on
   `edit`, which is how a reschedule plus its description text are corrected in one
   call rather than `config set` on a nested path.

   Finish when the readback shows `enabled: true` and a `nextRunAtMs` in the
   future — `cron get` is the proof, not the command's own exit code.

   **For a cost freeze (stop paid-provider burn), audit four layers — a paid
   fallback still fires when the primary fails, and a cron payload overrides the
   global default, so clearing only the primary leaves burn paths open.**
   Summarise every job's `payload.model`/`fallbacks`/`thinking` in one `cron
   list --json` pass, then read `agents.defaults.model` and
   `agents.entries.<id>.heartbeat.model`. Switch each paid model to the free
   target with its full `provider/model` id plus `--thinking` (prefer the full
   id over a short alias, which can resolve ambiguously), drop paid entries
   from every fallback list, and finish with a config-wide scan proving zero
   paid refs outside the model catalog. Verify with a re-list, not the edit
   exit code. Finish when no automated surface names a paid model.

   **A same-minute cluster means a bulk action, not a single click.** Observed:
   three unrelated jobs flipped to `enabled: false` within six seconds of each
   other (14:10:18, :23, :24). Treat that as one deliberate or automated sweep and
   say so — re-enable only the jobs the user actually asked about, and name the
   others you left off rather than silently restoring them.

   **The same sweep archives the jobs' cron sessions, so a re-enable alone leaves
   them failing.** Verified: the four jobs disabled in that window had their
   `agent:<agentId>:cron:<jobId>` rows archived in the same 16-second span
   (14:10:08–:24), and the one job that stayed enabled was the only cron session
   with no `archivedAt`. Re-enabling the flag then still dies at work-start with the
   archived-session error from step 2 — so after a cluster, always check and clear
   the matching sessions too, and do not report a job as restored until a run
   succeeds (step 2).

   **Do not infer the disable from the calendar.** "No message on a show day" is a
   symptom, not a cause: check the flag first, then the trigger, then the payload.
   Conversely, a sparse run history is not evidence of a disable — the job's own
   schedule (e.g. Tue–Thu only) legitimately produces empty days. And re-enabling
   does not retroactively deliver a missed day: if the payload already wrote its
   own record (a DB row, a sent marker), the next tick exits silently by design,
   so hand the user the recovered content directly and say why no message follows.

1. **Separate "the job ran" from "the payload did something".** A job can report
   `lastRunStatus: ok` while producing no visible result, because a payload that
   exits 0 with empty stdout is indistinguishable from "nothing to do yet". Run
   the payload command directly before blaming the scheduler: if it now prints
   the expected output, the job wiring is fine and the fault is in the trigger
   gate or the run environment. Finish when you can say which of the two layers
   is broken. Do not re-run the job as the first move.

2. **Read the job's error text first; an "archived session" block is a first-class
   signature.** `openclaw cron list --json` (or `cron get <jobId>`) exposes
   `state.lastError` and `consecutiveErrors`. When the text reads
   `Session "agent:<agentId>:cron:<jobId>" is archived. Restore it before starting new work.`,
   the run was refused at work-start because the job's own session row has `archivedAt`
   set — the job is fine, the session was archived. Do not assume the session cap: the
   verified cause here was a bulk sweep that archived the sessions and disabled the jobs
   together (step 0), so read the session's `archivedAt` and compare it with the job's
   `updatedAtMs` before naming a cause. Unarchive it (no restart needed). The CLI has no
   `unarchive` subcommand; `sessions.patch` is the Control UI's own path, reached over the
   gateway RPC:

   ```bash
   # sessionId from: openclaw sessions list --agent <agentId> --json
   openclaw gateway call sessions.patch --params '{"key":"<sessionKey>","archived":false,"expectedSessionId":"<sessionId>"}' --json
   ```

   To clear several at once, the `sessions` tool's `patch` takes a `targets` array of
   `{sessionKey, expectedSessionId}` — verified restoring four cron sessions in one call
   (`{"status":"updated","succeeded":[0,1,2,3],"failed":[]}`).

   **Issue both calls from the CLI: the `sessions` tools validate their arguments more
   strictly than the gateway does.** The `sessions` tool's `patch` answers
   `Invalid arguments … archived: must be boolean` for `archived:false`, and `sessions_list`
   rejects a numeric `limit` and a `kinds` array that the CLI accepts. The CLI paths take
   them and return the data: the `gateway call` above answers `ok:true` with
   `archivedAt`/`archivedBy` cleared, and `openclaw sessions list --agent <agentId> --json`
   returns a `sessions` array whose `agent:<agentId>:cron:<jobId>` rows carry the
   `sessionId` the patch needs. That listing's `archived` field can read `null` for an
   archived row, so confirm archived-ness from the job's `state.lastError` text, not from
   the listing.

   **`expectedSessionId` is mandatory** — omit it and nothing changes; the call returns
   `INVALID_REQUEST: expectedSessionId required for session lifecycle patch`. Success shows
   `ok:true` with `archivedAt`/`archivedBy` cleared. Prove it with a real run
   (`openclaw cron run <jobId> --wait --wait-timeout 5m --json`): `state.lastError`/
   `consecutiveErrors` keep the stale failure until that succeeding run, so the cleared
   timestamp alone is not the proof. Finish when the manual run reports `status: ok`.

3. **A `timeout` in the run record is the trigger evaluation, not the payload.**
   `cron trigger evaluation failed (timeout)` with a duration near the scheduler
   limit means the gate script did not finish — commonly host CPU starvation from
   unrelated processes, not a bug in the job. Check load (`uptime`) and top
   consumers before touching the job. Finish with the timeout attributed to
   either load or the script itself.

4. **Never build a calendar gate from a localized date string.** This is the
   highest-value trap in this skill and it fails *silently*:

   ```js
   // WRONG — parses "8.10.2026" as US format → August 10
   const d = new Date(now.toLocaleString('de-DE', { timeZone: 'Europe/Berlin' }))
   ```

   `toLocaleString` output is for humans, not `new Date()`. The swap hits every
   day ≤ 12 in any month > 12, so a gate keyed on month/day windows misfires for
   much of the year (measured: 88 mismatched days across one year). Read the
   parts instead:

   ```js
   const p = new Intl.DateTimeFormat('en-GB', {
     timeZone: 'Europe/Berlin', month: 'numeric', day: 'numeric'
   }).formatToParts(new Date())
   const month = +p.find(x => x.type === 'month').value
   const day   = +p.find(x => x.type === 'day').value
   ```

   Prefer `formatToParts` (or `Temporal`) for any timezone-aware date arithmetic.
   Finish when the gate's month/day values are proven correct for the current
   date, not merely that the script ran.

5. **Reach run history older than the ring buffer.** `openclaw cron runs <jobId>`
   returns only a short recent window (~7 entries observed) regardless of
   `--limit`; older runs are simply not in it. Do not read that truncation as
   "the job only ran 7 times" or as a gap. The durable per-run record is the
   `cron_run_receipts` table in the state database (`status`, `started_at_ms`,
   `finished_at_ms`, `error_text`) — read it with `node:sqlite` on a **private
   copy** of the state DB, never the external `sqlite3` CLI against the live
   state directory (its refusal is a guard, not corruption; the copy and safety
   rules are in `triage-sqlite-backup-failures`). Prove the method can see
   failures at all — e.g. count non-`ok` rows across all jobs — before reporting
   "zero failures", so a working column is not mistaken for a clean history.

Verification: the `enabled` flag was read first (and any disable reported with its
timestamp before deeper diagnosis); the failing layer (disabled flag, trigger gate, run
environment, payload, or an archived session) is named; any date gate is proven against the
current date; an archived-session block is cleared with `sessions.patch` (with
`expectedSessionId`) and proven by a succeeding manual run, not by the cleared timestamp; a
history claim rests on the receipts table rather than the truncated `cron runs` window, and
the query was shown able to surface failures.
