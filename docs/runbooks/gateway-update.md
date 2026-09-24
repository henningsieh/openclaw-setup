# Gateway Update Runbook

How to update the Shelldon OpenClaw gateway. Governance: ADR 0004 (system
unit), ADR 0005 (self-restart, watchdog, tmp lifecycle). Upstream reference:
`install/updating.md` (append `.md` per the repo URL rule).

## Iron rules

- Run everything from an **SSH terminal outside the gateway** — never from an
  agent turn or chat shell. Upstream forbids service stops and
  `npm install -g` from gateway-hosted shells (in-turn `systemctl`
  deadlocks against the shutdown drain; see ADR 0005).
- The watchdog must be paused for the whole procedure, otherwise it restarts
  the gateway mid-update. Pause with `touch ~/.openclaw/.maintenance`
  (the alias `.maintainance` works too); re-arm with `rm` afterwards.
- `openclaw doctor --fix` only runs with the gateway **stopped** — a running
  gateway holds the state lease and doctor fails with contention.

## Path A — coordinated update (default)

```bash
openclaw update --dry-run   # preview planned actions, no writes
openclaw update             # checks while serving, activates, verifies
openclaw update status      # read the active/last run report (--json available)
```

The updater stops/starts the managed service itself and posts milestones.
If it reports success, skip to Verification. If it reports abandoned state
or reconciliation warnings, continue with `openclaw update repair`, then
Verification. Chat alternative: `/update` (requires `commands.restart` plus
owner permissions; notices go to owner destinations only).

## Path B — manual fallback (recovery only)

```bash
# 0. Verified backup (see CONTEXT.md "Official OpenClaw backups").
openclaw backup create --output /mnt/openclaw-backup --verify

# 1. Pause the watchdog.
touch ~/.openclaw/.maintenance

# 2. Stop and wait for inactive.
sudo systemctl stop openclaw-gateway.service
until [ "$(systemctl is-active openclaw-gateway.service)" = "inactive" ]; do sleep 5; done

# 3. Update, repair only if the report demands it.
openclaw update
openclaw update repair   # only on abandoned-update / reconciliation reports

# 4. Migrate with the gateway stopped.
openclaw doctor --fix --non-interactive

# 5. Start and wait for readiness (plugin load takes ~45s).
sudo systemctl start openclaw-gateway.service
until curl --fail --silent --output /dev/null http://127.0.0.1:18789/; do sleep 5; done
journalctl -u openclaw-gateway.service --since "-3 min" | grep "http server listening"
# Expect the full plugin set incl. codex; compare count with the previous boot.

# 6. Re-arm the watchdog — never skip.
rm ~/.openclaw/.maintenance
```

## Verification

- `openclaw gateway status --deep` — service active, probe reachable.
- Control UI loads via `https://ai.sieh.org/`; Discord/Telegram respond.
- `openclaw update status` shows the new version as last run.
- The boot wiped `~/.openclaw/tmp` and `/tmp/openclaw-plugin-build-*`
  (ExecStartPre hook), so post-update debris self-cleans.

## Failure branches

- Update fails pre-activation: previous package stays live; read the failure
  report, resolve (often Node/npm perms or plugin availability), retry Path A.
- Update fails post-commit: package rollback cannot undo migrated state —
  finish with `openclaw doctor --fix` on the installed build, then
  `openclaw gateway start` (upstream recovery procedure).
- Gateway won't start: `journalctl -u openclaw-gateway.service -n 100`;
  common causes are config errors (doctor flags them) or a full disk
  (the boot hook cleans tmp, but check `df -h /`).
- Watchdog suspected of interfering: check for the guard file; without it,
  the watchdog only touches `inactive`/`failed` units and skips transitions.
