# Gateway Update Runbook

How to update the Shelldon OpenClaw gateway. Governance: ADR 0004 (system
unit), ADR 0005 (self-restart, watchdog, tmp lifecycle). Upstream reference:
`install/updating.md` (append `.md` per the repo URL rule).

## Host constraint: stop the gateway first

The gateway is a **system-scope systemd unit** (`/etc/systemd/system/`). The
OpenClaw updater cannot inspect or manage such a unit and says so explicitly:

```
Warning: Gateway service inspection is unavailable; automatic service restart
was skipped. Restart the Gateway you launched manually after the update.
```

Consequence, learned the hard way on 2026-09-24: with the gateway running, the
updater skips the service stop, then its activation doctor step fails with
`agent-database-lease-active` ("an agent database is in use") because the
running gateway holds the agent-database leases. The run rolls back and the
release is never applied.

**Therefore: the operator stops the gateway before the update and starts it
afterwards.** That is the procedure — not a workaround, and not optional.

## Iron rules

1. **Supported interfaces only.** Use `openclaw update`, `openclaw update
   status`, `openclaw update repair`, `openclaw doctor`, `systemctl`, and
   `curl`. **Never open, query, copy, or inspect OpenClaw's SQLite databases**
   during an update: the CLI reports everything needed, and stray database
   access is exactly the contention that fails activation.
2. **Never stop or restart the service from an agent turn.** An in-turn
   `sudo systemctl stop/restart` deadlocks against the gateway's shutdown
   drain until the stop timeout SIGKILLs everything (ADR 0005). Service
   control happens in the operator's terminal.
3. **No extra flags.** Run `openclaw update --yes`. Do not add `--no-restart`,
   `--tag`, or channel overrides for a routine update.
4. **Pause the watchdog** for the whole window:
   `touch ~/.openclaw/.maintenance` (alias `.maintainance` honored). Remove it
   only after verification — a guard left behind means an unguarded dead
   gateway later.
5. **`openclaw doctor --fix` only with the gateway stopped.** A running
   gateway holds the state lease.
6. **No agent session can complete this alone.** Stopping the gateway ends the
   agent's own session. The operator runs the sequence; an agent may preflight
   before and verify after.

## Procedure (operator, SSH terminal)

```bash
# 1. Pause the watchdog.
touch ~/.openclaw/.maintenance

# 2. Stop the gateway and wait for inactive.
sudo systemctl stop openclaw-gateway.service
until [ "$(systemctl is-active openclaw-gateway.service)" = "inactive" ]; do sleep 5; done

# 3. Confirm the ground is clear (CLI + process view only).
openclaw update status          # an unfinished run here => run `openclaw update repair --yes` first
pgrep -af openclaw-update || echo "no updater running"

# 4. Update. Foreground is correct here; expect roughly 15-20 minutes.
openclaw update --yes

# 5. Doctor with the gateway still stopped (the updater already ran it; repeat
#    only if the report asks for deferred checks).
openclaw doctor --fix --non-interactive

# 6. Start and wait for readiness (plugin load takes ~45s).
sudo systemctl start openclaw-gateway.service
until curl --fail --silent --output /dev/null http://127.0.0.1:18789/; do sleep 5; done

# 7. Verify.
openclaw --version                                    # expect the target release
openclaw update status                                # terminal, succeeded
openclaw gateway status --deep
journalctl -u openclaw-gateway.service --since "-5 min" | grep "http server listening"
# Expect the full plugin set including codex; compare with the previous boot.

# 8. Re-arm the watchdog — never skip.
rm ~/.openclaw/.maintenance
```

## Verification checklist

- `openclaw --version` shows the target release.
- Service `active`, HTTP 200 on `127.0.0.1:18789`.
- `openclaw update status` reports the run terminal (`succeeded`).
- Control UI loads via `https://ai.sieh.org/`; Discord/Telegram respond.
- Guard file gone; `systemctl --user list-timers | grep openclaw` shows the
  watchdog armed.
- The boot wiped `~/.openclaw/tmp` and `/tmp/openclaw-plugin-build-*`
  (ExecStartPre hook), so post-update debris self-cleans.

## Failure branches

- **`doctor-failed` / `agent-database-lease-active`:** the gateway was still
  running. It holds the agent-database leases. Stop it and re-run step 4.
  The run rolls back on its own; the live release is untouched.
- **Unfinished run in `openclaw update status`:** `openclaw update repair --yes`,
  then re-run step 4.
- **`managed-service` warning in the report:** expected on this host. It only
  means the updater did not touch the service; steps 2 and 6 cover that.
- **Failed after the package swap:** package rollback cannot undo migrated
  state. Finish with `openclaw doctor --fix` on the installed build, then
  start the service.
- **Gateway won't start:** `journalctl -u openclaw-gateway.service -n 100`;
  common causes are config errors (doctor flags them) or a full disk
  (`df -h /`).
- **Installation considered unrecoverable:** the updater points at
  `openclaw triage`. Treat that as a human decision, not an automatic step.
