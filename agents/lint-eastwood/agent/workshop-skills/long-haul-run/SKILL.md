---
name: long-haul-run
description: Heavy builds and staged test-evidence campaigns; log to file, poll milestones, verify the served build, prove pre-existing failures by baseline run.
---

# Long-haul run

Run an hours-long build or suite so progress survives the turn and milestones reach the user without spam.

## Steps

1. Record a pre-flight baseline first (`free -m`, `uptime`), because timeouts under swap pressure are environmental and the baseline is the evidence. Then launch with exec `background:true` and an explicit `timeoutSeconds` comfortably above the expected duration (for example 1800 for a suite expected to take 10+ minutes), because the default timeout SIGTERMs the run mid-suite and the kill looks like a suite failure (exit 143), and pipe stdout and stderr through `tee` to a timestamped logfile (for example `.turbo/full-tests/run-<id>.log`), then keep both the returned `sessionId` and the log path, because a bare `nohup ... &` dies silently with the call and leaves an empty log. End the pipeline with `echo "EXIT:${PIPESTATUS[0]}"` so the log carries the runner's true exit code, because `$?` after a pipe reports the last stage, not the runner. Re-verify every background service the run depends on before each dependent stage and restart it with the same start command when its health check fails, because holder sessions can expire mid-campaign and take the service down with them; after a restart that must pick up a rebuild, also confirm the served build is the new one (build artifact mtime newer than the code change, plus one smoke request), because a 200 health check only proves the old build is up. When running a scoped subset outside the repo's own script, read the harness source first and replicate how it builds the runner environment (env files, base URLs, service handles), because a bare direct invocation misses harness-injected variables and fails on config validation.
2. Poll the logfile for milestone events (group PASSED/FAILED lines, counts, phase markers) instead of raw process output, because background output is truncated and completion is silent. Report per-suite totals by grepping the logfile (`grep -E '^(PASSED|FAILED)' <log>`, `grep -E 'passed|failed' <log> | tail`) together with the candidate-commit and exit lines, because a multi-suite run overflows the tail buffer and a report that silently drops one suite cannot be checked.
3. Keep the machine quiet for the whole run: no parallel builds, suites, or dev servers, since contention on this box turns into timeouts that look like real failures. Free a stuck test port with `fuser -k PORT/tcp`, never with a `pkill -f` pattern that also appears in your own command line, because the pattern matches your own shell and kills it.
4. Report milestones every 5 to 20 minutes with observed counters only, and attach a fresh log read to every reply until the run ends, because any user message answered without a status forces them to ask again; then the final result with the log path and retained evidence directories.

## Rules

- Launch the run in the same turn it was ordered, because a promised later start becomes hours of idle waiting with nothing to report; when the start truly depends on a condition, keep polling for that condition instead of ending the turn.
- Report only counters and states already present in the log, because invented progress destroys trust in the next milestone.
- Never promise unsolicited timed pings, because messages only go out on user turns and the promise is unkeepable; offer the logfile as the live record plus an instant fresh answer on every check-in instead.
- Before re-running a failed suite, exhaust the retained evidence (run log, result JSON, prior green report) for the cause, because a re-run costs hours and the failure signature is usually already recorded.
- When a suite or stage name contains `merge`, qualify it as a test suite and never imply a Git merge; if the user asks about a conflict, show `git status --short`, `git ls-files -u`, and whether `.git/MERGE_HEAD` exists, because the word "merge" in test output is not a repository merge.
- Verify the checkout (branch, expected tip hash, clean tree) and every dependent service's health before each stage, and hold with a report instead of proceeding on any mismatch, because evidence collected on the wrong revision is worthless.
- Never run destructive sync (reset --hard, branch delete/recreate, forced updates) without explicit approval, because overwritten history is unrecoverable.
- Leave the repository untouched during an evidence campaign (no pushes, merges, or closes) unless that exact action was ordered, because the campaign's value is an untouched revision the user verifies themselves.
- Classify a failure cluster by its signature before reporting it: repeated `ECONNREFUSED` or `net::ERR_CONNECTION_REFUSED` means the service died mid-run, so restart it under a longer holder, re-run the stage, and state that the earlier numbers were contaminated by the outage, because reporting artifacts as test failures sends the user chasing a bug that does not exist.
- To prove a failure is pre-existing, run the same specs against the comparison ref in a separate worktree with its own ports and copied env files, with the campaign servers stopped to free memory, and rebuild the app under test with the port base URLs because `NEXT_PUBLIC_*` values are inlined at build time; report identical signatures as pre-existing and differing signatures as caused by the change.
