# Prompt: Recover Abandoned Update and Upgrade Gateway to 2026.9.6

**How to use:** start a fresh Pi session with cwd `/home/shelldon/.openclaw`
and paste the prompt body below verbatim. It is written to be executed by an
agent turn, under the constraints of `docs/runbooks/gateway-update.md` and
ADR 0005.

---

You are operating on the native OpenClaw host `ubuntu-8gb-nbg1-1` as user
`shelldon`. Your mission has exactly two parts:

1. **Recover** the abandoned update run (`openclaw update repair`).
2. **Update** OpenClaw to the latest release, `2026.9.6` (npm, stable channel).

## Read first

- `docs/runbooks/gateway-update.md` — the authoritative procedure, including
  the agent-executable variant. Follow it exactly.
- `docs/adr/0005-self-restartable-gateway-and-tmp-lifecycle.md` — why in-turn
  service control is forbidden.
- `CONTEXT.md` → "Service management" — unit name, paths, verification.

## Current state (2026-09-24, ~10:30 CEST)

- Gateway `openclaw-gateway.service`: **active, HTTP 200**, running
  **2026.9.5**. Not broken; no partial application.
- Target: **2026.9.6** (npm, channel `stable`).
- **Abandoned run:** `run_id d91d9cf4-f052-44dd-bee9-d6a43dd44ad8`,
  trigger `cli`, phase `validating`, `status=running`, driver
  `pid=3783597` — that process is **gone**. The row never terminalized.
- **Guard present:** `~/.openclaw/.maintenance` exists (watchdog paused).
  Keep it until verification passes.
- Previous `openclaw update --dry-run` run exists and is terminal — ignore it.

## Hard constraints (violating these is the failure mode to avoid)

- **Never** run `systemctl stop/restart openclaw-gateway.service` in your own
  turn. It deadlocks against the shutdown drain and SIGKILLs everything after
  330s (ADR 0005). Only `~/.local/bin/openclaw-gateway-restart-detached` is
  agent-safe, and this procedure should not need it at all.
- **Never** pass `--no-restart`. The updater must own stop/start on this
  system unit.
- **Never** block on the updater inline. Launch it detached with
  `nohup … &` and **poll** `openclaw update status`. Tool timeouts (~90s) kill
  inline drivers mid-phase and create exactly the abandoned run you are
  repairing.
- **Never** re-launch an update while a run row is still `running` with a
  live driver.
- `openclaw doctor --fix` **only** with the gateway stopped.
- **Your session will drop** when the gateway restarts. That is expected —
  do not fight it, do not treat it as a failure.
- Remove the guard **only** after verification passes. If anything fails,
  leave the guard in place and report.

## Steps

**0. Preflight.** Confirm and record, don't change anything:

```bash
systemctl is-active openclaw-gateway.service
curl --fail --silent --output /dev/null http://127.0.0.1:18789/ && echo "HTTP OK"
openclaw --version
ls -la ~/.openclaw/.maintenance
openclaw update status
# Confirm the abandoned run: driver PID from the running row, then check liveness.
sqlite3 ~/.openclaw/state/openclaw.sqlite \
  "SELECT run_id, phase, status, json_extract(origin_json,'\$.driver.pid') FROM update_runs WHERE status='running';"
```

If a driver PID **is** alive, stop and report — a real update is in flight
and you must wait for it, not repair it.

**1. Recovery.** Run repair detached, then poll to a terminal state:

```bash
LOG=~/.openclaw/logs/update-repair-$(date +%Y%m%dT%H%M%S).log
nohup openclaw update repair --yes >"$LOG" 2>&1 &
echo "repair launched detached; log=$LOG"
openclaw update status        # repeat every ~60s until terminal
```

A "nothing to repair" outcome is fine — proceed.

**2. Update.** Launch detached, then poll. Do not re-launch:

```bash
LOG=~/.openclaw/logs/update-$(date +%Y%m%dT%H%M%S).log
nohup openclaw update --yes >"$LOG" 2>&1 &
echo "update launched detached; log=$LOG"
openclaw update status        # repeat every ~60s until terminal
```

Expected: phases `requested → staging → validating → activating → restarting
→ verifying → finished`, status `succeeded`. The gateway restarts inside
this window and your session drops.

**3. Verification** (after the run is terminal; new turn if the session dropped):

```bash
openclaw --version                                    # expect 2026.9.6
systemctl is-active openclaw-gateway.service           # expect active
curl --fail --silent --output /dev/null http://127.0.0.1:18789/ && echo "HTTP OK"
openclaw gateway status --deep
openclaw update status                                 # terminal, new version
journalctl -u openclaw-gateway.service --since "-5 min" | grep "http server listening"
# Expect the full plugin set including codex.
```

**4. Re-arm the watchdog** (only after step 3 passes):

```bash
rm ~/.openclaw/.maintenance
systemctl --user list-timers | grep openclaw
```

**5. Report** in this shape, nothing longer:

- Version before → after
- Update run id, phases, status, downtime
- Repair outcome
- Gateway/service/HTTP/plugin verification results
- Guard removed: yes/no
- Anything unresolved, with the exact next command

## If the session drops mid-update

Continue in a new turn: re-run step 0's status checks, confirm the run is
terminal, then do step 3. Never relaunch a run that is still `running` with a
live driver.

## Failure branches

Follow `docs/runbooks/gateway-update.md` → "Failure branches". In short:
aborted/killed run → `openclaw update repair` and retry; failure
pre-activation → previous package stays live, resolve and retry; failure
post-commit → package rollback cannot undo migrated state, finish with
`openclaw doctor --fix` on the installed build, then start the service. Leave
the guard in place until the gateway is verified healthy.

## Optional follow-up

If this procedure reveals a gap or a wrong instruction in
`docs/runbooks/gateway-update.md`, fix the runbook and commit **only** that
path (and `CONTEXT.md` if it changed) on branch `native-setup`. Do not commit
unrelated staged work from other sessions.
