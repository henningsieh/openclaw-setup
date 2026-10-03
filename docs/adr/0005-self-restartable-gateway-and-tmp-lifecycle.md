# Self-Restartable Gateway and Boot-Scoped Temp Lifecycle

## Status

Accepted 2026-09-23. Amended 2026-09-24 (Amendment A: in-process restart loophole closed after the 13:24 CEST incident — see below). Implements the owner's requirement that the Shelldon
agent can restart its own gateway without killing it, and that gateway temp
state cannot fill the host disk.

## Context

On 2026-09-23 the gateway died repeatedly and stayed down. Diagnosis showed
three stacked causes:

1. **In-turn `systemctl restart` deadlocks.** A blocking `systemctl` client
   spawned from an agent turn is a child of the gateway, while the gateway's
   shutdown drain waits on the requesting agent run. Gateway waits on run,
   run waits on client, client waits on gateway — until `TimeoutStopSec`
   (330s) expires and everything is SIGKILLed. `openclaw gateway restart`
   is not an alternative: it refuses system-scope units.
2. **Explicit `stop` stays stopped by design.** systemd does not apply
   `Restart=always` after an intentional stop, and repeated kill-cycles park
   the unit in `failed (Result: signal)` behind the start limit. Twice an
   agent turn issued `stop` from the workspace and the gateway never returned.
3. **Temp accumulation.** Every boot captures each plugin into fresh
   `mkdtemp("openclaw-plugin-build-")` dirs and every new agent session
   prepares further plugin installs (`prepared-runtime`, ~24s each). Old
   captures are never disposed: shutdowns are SIGKILLs (wedged 315s drain on
   discord/telegram admitted work), and runtime captures have no disposal
   path at all. `/dev/sda1` (75G) hit 100% twice; the resulting `ENOSPC`
   broke SQLite writes and plugin loads, accelerating the death spiral.

## Decision

- **Agent self-restart goes through a detached wrapper only:**
  `~/.local/bin/openclaw-gateway-restart-detached` runs the exact
  sudoers-covered `sudo -n systemctl restart openclaw-gateway.service` via
  `setsid` in the background and returns in milliseconds, so the requesting
  turn completes and the drain has nothing to deadlock on. **All other
  restart/stop triggers from agent turns are forbidden**, namely: raw
  `systemctl stop/restart`, `openclaw gateway restart` in ANY form (plain,
  `--safe`, `--force`, `--wait`, `--skip-deferral`), `SIGUSR2` / `kill
  -USR2` / `gateway.restart.safe` (in-process restart, same PID), any
  gateway restart tool/API call, and any Control UI restart button. The
  requesting session drops on restart by design; recovery is verified in a
  new turn. Verification is a PID change plus the systemd journal — plan
  text claiming the "approved detached path" proves nothing.
- **A user-scope watchdog heals any residue:**
  `openclaw-gateway-watchdog.{service,timer}` (user manager, every 3 min)
  issues `sudo -n systemctl restart` when the unit is `inactive`/`failed`,
  skips transient states (`activating/deactivating/reloading`), and respects
  the `~/.openclaw/.maintenance` guard file (alias `.maintainance` honored)
  for intentional downtime.
- **Boot wipes temp via the service lifecycle, no sweepers:**
  `/etc/systemd/system/openclaw-gateway.service.d/30-tmp-clean.conf` runs
  two `ExecStartPre` finds on every boot: one over `~/.openclaw/tmp`, one
  over `/tmp/openclaw-plugin-build-*` excluding `*.md` (a handoff document
  lives under that name pattern and must survive). The second line exists
  because plugin builds spawned from worker processes run with a scrubbed
  environment (no `TMPDIR`), so `mkdtemp` falls back to system `/tmp` —
  every boot sprays both locations. Root-owned strays are silently skipped.
  Verified: 24 dirs before, 0 stale survivors after.
- **No source edits, no new credentials, no sudoers changes.** Everything
  above uses the existing NOPASSWD verbs and shelldon-owned paths, except
  the single root-owned drop-in installed once by the owner.

## Consequences

- **Updates on this host require the operator to stop the gateway first.**
  The gateway is a system-scope systemd unit, which the OpenClaw updater
  cannot inspect or manage; it reports `Gateway service inspection is
  unavailable; automatic service restart was skipped`. Running the updater
  with the gateway up fails activation with `agent-database-lease-active`
  (the running gateway holds the agent-database leases) and rolls back. The
  operator stops the unit, runs the update, then starts it. For an agent, the
  sanctioned path is the tracked `scripts/gateway-update.sh` lifecycle,
  launching one detached `setsid` session (stop → update → local-plugin
  rebuild/test/install → final Doctor → start → verify → owner confirmation
  → re-arm watchdog). It attempts service recovery on failure; recovery is
  not success. See `docs/runbooks/gateway-update.md`.
- Restarts return in seconds when shutdown is clean, and always recover via
  the watchdog when shutdown wedges (worst case ~6 min through the stop
  timeout, then start). "Gateway never comes back" is structurally closed.
- Boot orphans are eliminated permanently; disk use is bounded by one
  uptime's worth of temp instead of growing since install.
- **Known residual (upstream bug):** per-session runtime installs during a
  long uptime still accumulate until the next restart, because upstream
  dispose logic never fires for them. Mitigation is restarts plus this ADR's
  boot wipe; the durable fix belongs upstream (evidence prepared for
  `openclaw/openclaw` issue: fresh-dir-per-boot plus per-session prepares
  plus dispose-never-fires plus SIGKILL shutdowns).
- `TimeoutStopSec=330s` still dominates wedged restarts (telegram
  reconnect-drain hangs server close until the deadline). Lowering it needs
  root and risks interrupting SQLite WAL writes; deferred until the drain
  hang is understood upstream.

## Amendment B (2026-10-03): persisted update lifecycle

The one-off update chain is replaced by tracked `scripts/gateway-update.sh`.
Its Bash entry point delegates lifecycle bookkeeping to a Python standard-library
module. `start_new_session=True` invokes the native `setsid` mechanism; it is
not an inline stop/restart loophole. `start` returns without waiting on the
service drain, while the worker holds the inherited lifecycle lock.

The script refuses competing maintenance and existing guards, records a unique
run identity, rebuilds the local broker after core replacement, and requires
final Doctor completion before normal activation. Its recovery path attempts
service startup even on failure and explicitly preserves the failed result.
Automatic checks end in `awaiting-confirmation`; `finish` requires owner UI
confirmation and removes only that run's guard, with watchdog verification.
Private receipts/guards stay outside Git. The operational interface and failure
branches have one source of truth in `docs/runbooks/gateway-update.md`.

The 2026.9.8 maintenance window exceeded earlier timings. No ETA is guaranteed;
external Pi sessions monitor through startup rather than ending after launch.
This does not add a new restart trigger, change watchdog scheduling, weaken
Vault Retrieval Approval, or replace boot temp cleanup.

## Amendment A (2026-09-24): in-process restart loophole

 Incident: at 13:24 CEST an agent turn logged "restarting the Gateway
 through the approved detached path", ran `sessions.abort`, then triggered
 `SIGUSR2: gateway.restart.safe`. PID stayed `4036061` before and after
 (`restart mode: in-process restart (OPENCLAW_NO_RESPAWN)`), all webchat
 dropped (`1012 service restart`), ~90s outage. The detached wrapper was
 NOT used — it performs a systemd restart with SIGTERM and a new PID.
 Root cause: this ADR (written against core `2026.9.5`) described `openclaw
 gateway restart` as "refuses system-scope units, not an alternative". On
 core `2026.9.6` that command no longer refuses — `--safe` performs a
 SIGUSR2 in-process restart that bypasses systemd and the deadlock
 reasoning entirely. The original wording named only the systemctl path
 and left the in-process path uncovered. This amendment closes the gap:
 the Decision bullet above now forbids every in-turn restart trigger except
 the detached restart wrapper (and the tracked update lifecycle, which is
 the same detached mechanism extended). The runbook's service-control
 guardrails match this restriction.
