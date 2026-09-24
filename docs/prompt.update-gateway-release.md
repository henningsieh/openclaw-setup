# Prompt: Update the OpenClaw Gateway

**How to use:** start a fresh Pi session with cwd `/home/shelldon/.openclaw`
and paste the prompt body below verbatim. It is evergreen — it names no
version, date, or run id — and follows `docs/runbooks/gateway-update.md` and
ADR 0005.

---

You are operating on the native OpenClaw host as user `shelldon`. Your job is
to get the gateway updated to the latest release on the configured channel —
**without touching any OpenClaw database, and without inventing workarounds.**

## Read first

- `docs/runbooks/gateway-update.md` — the authoritative procedure.
- `docs/adr/0005-self-restartable-gateway-and-tmp-lifecycle.md` — why in-turn
  service control is forbidden.

## Why this is a hand-off, not a solo job

The gateway is a **system-scope systemd unit**, which the OpenClaw updater
cannot manage — it reports `Gateway service inspection is unavailable;
automatic service restart was skipped`. So the gateway must be **stopped
before** the update runs, and stopping it ends your own session. You cannot
complete the sequence alone; the operator runs it in their terminal.

## Hard rules

- **Never open, query, copy, or inspect OpenClaw's SQLite databases.** No
  `sqlite3`, no file copies, no lock hunting. `openclaw update status` is the
  only source of truth you need.
- **Never run `systemctl stop/restart openclaw-gateway.service` in your own
  turn.** It deadlocks against the shutdown drain until the stop timeout
  SIGKILLs everything (ADR 0005). Only
  `~/.local/bin/openclaw-gateway-restart-detached` is agent-safe, and this
  procedure does not need it.
- **No extra flags:** the update command is exactly `openclaw update --yes`.
  Never `--no-restart`, `--tag`, or channel overrides for a routine update.
- **No polling loops.** Do not run `sleep N; openclaw update status` in a loop:
  it keeps agent turns active, which blocks the gateway from draining.
- **No scripts, no background chains, no clever wrappers.** Straightforward
  commands only.
- Watchdog guard: `~/.openclaw/.maintenance` (alias `.maintainance`) must be
  present for the whole window and removed only after verification.

## Step 1 — Preflight (read-only, CLI only)

```bash
systemctl is-active openclaw-gateway.service
curl --fail --silent --output /dev/null http://127.0.0.1:18789/ && echo "HTTP OK"
openclaw --version
openclaw update status
pgrep -af openclaw-update || echo "no updater running"
ls -l ~/.openclaw/.maintenance 2>&1
```

Report what you found. If `openclaw update status` shows an unfinished run, or
an updater process is still alive, **stop and say so** — the operator must
resolve that first (the runbook covers it). Otherwise continue.

## Step 2 — Hand off to the operator

Pause the watchdog, then give the operator this block to run in their SSH
terminal. Tell them the gateway will go down and come back, and that it takes
roughly 15-20 minutes:

```bash
touch ~/.openclaw/.maintenance
sudo systemctl stop openclaw-gateway.service
until [ "$(systemctl is-active openclaw-gateway.service)" = "inactive" ]; do sleep 5; done
openclaw update --yes
sudo systemctl start openclaw-gateway.service
until curl --fail --silent --output /dev/null http://127.0.0.1:18789/; do sleep 5; done
```

Then **end your turn and stop polling.** Your session will drop when the
gateway stops; that is expected and not a failure.

## Step 3 — Verify (in a new turn, once the gateway is back)

```bash
openclaw --version
openclaw update status
systemctl is-active openclaw-gateway.service
curl --fail --silent --output /dev/null http://127.0.0.1:18789/ && echo "HTTP OK"
journalctl -u openclaw-gateway.service --since "-5 min" | grep "http server listening"
```

Then, only if everything above passed:

```bash
rm ~/.openclaw/.maintenance
```

If the version did not change, report the `openclaw update status` output
verbatim and stop — do not retry, do not improvise, do not start inspecting
databases.

## Report

- Version before → after
- Update run outcome (`openclaw update status`)
- Service, HTTP, and plugin verification results
- Guard removed: yes/no
- Anything unresolved, with the exact next command
