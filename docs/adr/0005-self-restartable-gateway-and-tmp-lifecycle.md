# Self-Restartable Gateway and Boot-Scoped Temp Lifecycle

## Status

Accepted 2026-09-23. Implements the owner's requirement that the Shelldon
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
  turn completes and the drain has nothing to deadlock on. Raw `systemctl
  stop/restart` inside agent turns, and `openclaw gateway restart` for this
  system-scope unit, are forbidden and documented as such. The requesting
  session drops on restart by design; recovery is verified in a new turn.
- **A user-scope watchdog heals any residue:**
  `openclaw-gateway-watchdog.{service,timer}` (user manager, every 3 min)
  issues `sudo -n systemctl restart` when the unit is `inactive`/`failed`,
  skips transient states (`activating/deactivating/reloading`), and respects
  the `~/.openclaw/.maintenance` guard file for intentional downtime.
- **Boot wipes temp via the service lifecycle, no sweepers:**
  `/etc/systemd/system/openclaw-gateway.service.d/30-tmp-clean.conf`
  runs `ExecStartPre=-/usr/bin/find ~/.openclaw/tmp -mindepth 1 -maxdepth 1
  -exec rm -rf {} +`. At that point the old process is guaranteed dead, so
  everything present is garbage by construction. Verified: 24 dirs before,
  0 stale survivors after. Rejected alternative: periodic cleanup scripts —
  lifecycle-coupled cleanup has no age math, no grace windows, no moving parts.
- **No source edits, no new credentials, no sudoers changes.** Everything
  above uses the existing NOPASSWD verbs and shelldon-owned paths, except
  the single root-owned drop-in installed once by the owner.

## Consequences

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
