# Prompt: Recover and Update the OpenClaw Gateway

**How to use:** start a fresh Pi session with cwd `/home/shelldon/.openclaw`
and paste the prompt body below verbatim. It is evergreen — it names no
version, date, or run id, and stays valid across releases. It is written to
be executed by an agent turn, under the constraints of
`docs/runbooks/gateway-update.md` and ADR 0005.

---

You are operating on the native OpenClaw host as user `shelldon`. Your
mission has exactly two parts:

1. **Recover** any abandoned update run (`openclaw update repair`). This is
   idempotent and harmless — if there is nothing to repair, it says so and
   you move on. Run it first so a stale run cannot block or confuse the
   update.
2. **Update** OpenClaw to the latest release on the configured channel.

## Read first

- `docs/runbooks/gateway-update.md` — the authoritative procedure, including
  the agent-executable variant. Follow it exactly.
- `docs/adr/0005-self-restartable-gateway-and-tmp-lifecycle.md` — why in-turn
  service control is forbidden.
- `CONTEXT.md` → "Service management" — unit name, paths, verification.

## Hard constraints (violating these is the failure mode to avoid)

- **Never** run `systemctl stop/restart openclaw-gateway.service` in your own
  turn. It deadlocks against the shutdown drain and SIGKILLs everything after
  the stop timeout (ADR 0005). Only
  `~/.local/bin/openclaw-gateway-restart-detached` is agent-safe, and this
  procedure should not need it at all.
- **Never** pass `--no-restart`. The updater must own stop/start on this
  system unit.
- **Never** block on the updater inline. Launch it detached with
  `nohup … &` and **poll** `openclaw update status`. Tool timeouts kill
  inline drivers mid-phase and create the abandoned run you are repairing.
- **Never** re-launch an update while a run row is still `running` with a
  live driver.
- `openclaw doctor --fix` **only** with the gateway stopped.
- **Your session will drop** when the gateway restarts. That is expected —
  do not fight it, do not treat it as a failure.
- Pause the watchdog for the whole window (`~/.openclaw/.maintenance`; alias
  `.maintainance` honored) and remove it **only** after verification passes.
  If anything fails, leave it in place and report.

## Steps

**0. Preflight.** Confirm and record, don't change anything:

```bash
systemctl is-active openclaw-gateway.service
curl --fail --silent --output /dev/null http://127.0.0.1:18789/ && echo "HTTP OK"
openclaw --version
openclaw update status
# Is a run row actually in flight, or is it abandoned?
sqlite3 ~/.openclaw/state/openclaw.sqlite \
  "SELECT run_id, phase, status, json_extract(origin_json,'\$.driver.pid') FROM update_runs WHERE status='running';"
```

For any PID returned, check `ps -p <pid>`. A live PID means a real update is
in flight: **stop and report**, wait for it to reach a terminal state; do not
repair or relaunch it. No row, or a row whose driver is gone, means you can
proceed — the latter is an abandoned run.

**1. Pause the watchdog.**

```bash
touch ~/.openclaw/.maintenance
```

**2. Recovery.** Run repair detached, then poll to a terminal state:

```bash
LOG=~/.openclaw/logs/update-repair-$(date +%Y%m%dT%H%M%S).log
nohup openclaw update repair --yes >"$LOG" 2>&1 &
echo "repair launched detached; log=$LOG"
openclaw update status        # repeat every ~60s until terminal
```

A "nothing to repair" outcome is expected and fine — continue.

**3. Update.** Launch detached, then poll. Do not re-launch:

```bash
LOG=~/.openclaw/logs/update-$(date +%Y%m%dT%H%M%S).log
nohup openclaw update --yes >"$LOG" 2>&1 &
echo "update launched detached; log=$LOG"
openclaw update status        # repeat every ~60s until terminal
```

Expected: phases `requested → staging → validating → activating → restarting
→ verifying → finished`, status `succeeded`. The gateway restarts inside
this window and your session drops.

**4. Verification** (after the run is terminal; new turn if the session dropped):

```bash
openclaw --version                                    # expect the target release
systemctl is-active openclaw-gateway.service           # expect active
curl --fail --silent --output /dev/null http://127.0.0.1:18789/ && echo "HTTP OK"
openclaw gateway status --deep
openclaw update status                                 # terminal, target version
journalctl -u openclaw-gateway.service --since "-5 min" | grep "http server listening"
# Expect the full plugin set including codex; compare with the previous boot.
```

**5. Re-arm the watchdog** (only after step 4 passes):

```bash
rm ~/.openclaw/.maintenance
systemctl --user list-timers | grep openclaw
```

**6. Report** in this shape, nothing longer:

- Version before → after (target from `openclaw update status`)
- Update run id, phases, status, downtime
- Repair outcome
- Gateway/service/HTTP/plugin verification results
- Guard removed: yes/no
- Anything unresolved, with the exact next command

## If the session drops mid-update

Continue in a new turn: re-run step 0's status checks, confirm the run is
terminal, then do step 4. Never relaunch a run that is still `running` with a
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
