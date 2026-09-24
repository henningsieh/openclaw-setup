# Gateway Update Runbook

How to update the Shelldon OpenClaw gateway. Governance: ADR 0004 (system
unit), ADR 0005 (self-restart, watchdog, tmp lifecycle). Upstream reference:
`install/updating.md` (append `.md` per the repo URL rule).

This runbook is written for **both** a human at an SSH terminal and an
**agent turn**. Where the two differ, the difference is called out
explicitly — do not assume a command is safe in a turn just because it is
safe at a terminal.

## Iron rules

1. **Never run the updater inline in an agent tool call.** Update steps run
   up to `--timeout` seconds (default 1800) each, and validation alone
   (canary boot) takes minutes; typical agent tool timeouts are ~90s. When
   the tool call is aborted, the driver process is killed mid-phase and
   leaves an **abandoned run row** (`status=running`, phase stuck). Agents
   must launch detached and poll (Path A, agent variant).
2. **Never stop or restart the service from an agent turn.** An in-turn
   `sudo systemctl stop/restart` deadlocks against the gateway's shutdown
   drain until the 330s timeout SIGKILLs everything (ADR 0005). The only
   agent-safe restart is `~/.local/bin/openclaw-gateway-restart-detached`.
   A human at SSH may use `sudo systemctl` directly.
3. **Never pass `--no-restart` for this installation.** It is a system unit
   managed by systemd; with `--no-restart` the updater leaves the service
   stale/stopped and you are tempted into an in-turn `systemctl restart`
   (rule 2). Let the updater own stop/start and its notifications.
4. **Pause the watchdog for the whole window.** `touch ~/.openclaw/.maintenance`
   (alias `.maintainance` honored). Remove it only after verification.
   A guard left behind means an unguarded dead gateway later.
5. **`openclaw doctor --fix` only with the gateway stopped.** A running
   gateway holds the state lease and doctor fails with contention.

## Path A — coordinated update (default)

Human at SSH:

```bash
openclaw update --dry-run     # preview planned actions, no writes
openclaw update               # checks while serving, activates, verifies
openclaw update status        # run report (--json for machine output)
```

Agent turn — same update, launched detached so a tool abort cannot kill it:

```bash
touch ~/.openclaw/.maintenance
LOG=~/.openclaw/logs/update-$(date +%Y%m%dT%H%M%S).log
nohup openclaw update --yes >"$LOG" 2>&1 &
echo "update launched detached; log=$LOG"
```

Then **poll to a terminal state** — never block on it, never re-launch it:

```bash
openclaw update status        # repeat every ~60s
```

Proceed to Verification once the report is `succeeded`/`failed`/
`rolled-back`/`skipped`. If it reports abandoned state or reconciliation
warnings, run `openclaw update repair`, then verify.

Chat alternative: `/update` (requires `commands.restart` plus owner
permissions; notices go to owner destinations only).

## Detecting an abandoned run

An update that "keeps running" with no process behind it is abandoned, not
in flight. Check before waiting on anything:

```bash
# driver PID of the running update row (empty = no run row in progress)
sqlite3 ~/.openclaw/state/openclaw.sqlite \
  "SELECT json_extract(origin_json,'\$.driver.pid') FROM update_runs WHERE status='running';"
ps -p <pid>    # gone => abandoned
```

Abandoned run → `openclaw update repair` (reconciles it), then re-run Path A.
Do **not** wait for an abandoned run to finish; it never will.

## Path B — manual fallback (recovery only, human at SSH)

```bash
# 0. Verified backup (see CONTEXT.md "Official OpenClaw backups").
openclaw backup create --output /mnt/openclaw-backup --verify

# 1. Pause the watchdog.
touch ~/.openclaw/.maintenance

# 2. Stop and wait for inactive.
sudo systemctl stop openclaw-gateway.service
until [ "$(systemctl is-active openclaw-gateway.service)" = "inactive" ]; do sleep 5; done

# 3. Update; repair only if the report demands it.
openclaw update
openclaw update repair   # only on abandoned-update / reconciliation reports

# 4. Migrate with the gateway stopped.
openclaw doctor --fix --non-interactive

# 5. Start and wait for readiness (plugin load takes ~45s).
sudo systemctl start openclaw-gateway.service
until curl --fail --silent --output /dev/null http://127.0.0.1:18789/; do sleep 5; done
journalctl -u openclaw-gateway.service --since "-3 min" | grep "http server listening"
# Expect the full plugin set incl. codex; compare the count with the previous boot.

# 6. Re-arm the watchdog — never skip.
rm ~/.openclaw/.maintenance
```

## Verification

- `openclaw --version` shows the target version (updates can leave the old
  version live if they fail before activation).
- `openclaw gateway status --deep` — service active, probe reachable.
- Control UI loads via `https://ai.sieh.org/`; Discord/Telegram respond.
- `openclaw update status` shows the run as terminal with the new version.
- `ls ~/.openclaw/.maintenance` — the guard is gone.
- The boot wiped `~/.openclaw/tmp` and `/tmp/openclaw-plugin-build-*`
  (ExecStartPre hook), so post-update debris self-cleans.

## Failure branches

- **Aborted/killed mid-run** (agent tool timeout, session end): the run row
  stays `running` with no live driver → `openclaw update repair`, re-run
  Path A detached.
- **Fails pre-activation:** previous package stays live; read the failure
  report, resolve (often Node/npm perms or plugin availability), retry.
- **Fails post-commit:** package rollback cannot undo migrated state —
  finish with `openclaw doctor --fix` on the installed build, then
  `openclaw gateway start` (upstream recovery procedure).
- **Service left stopped** after a failed update: an already-stopped service
  stays stopped until explicitly started. Start it, or let the watchdog do
  it once the guard is removed.
- **Gateway won't start:** `journalctl -u openclaw-gateway.service -n 100`;
  common causes are config errors (doctor flags them) or a full disk
  (`df -h /`).
- **Guard left behind:** the watchdog is paused; nothing heals a dead
  gateway. Remove the guard as soon as the window closes.
