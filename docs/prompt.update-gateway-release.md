# Prompt: Update the OpenClaw Gateway

**How to use:** start a fresh Pi session with cwd `/home/shelldon/.openclaw`
and paste the prompt body below verbatim. It is evergreen — no version, date,
or run id — and it is designed to **complete the update**, not to stop and
wait. Governance: `docs/runbooks/gateway-update.md`, ADR 0005.

---

You are operating on the native OpenClaw host as user `shelldon`. Your job is
to get the gateway updated to the latest release on the configured channel,
end to end, **without touching any OpenClaw database and without inventing
workarounds.**

## Read first

- `docs/runbooks/gateway-update.md` — the authoritative procedure.
- `docs/adr/0005-self-restartable-gateway-and-tmp-lifecycle.md` — why in-turn
  blocking service control is forbidden.

## The key fact

The gateway is a **system-scope systemd unit**, which the OpenClaw updater
cannot manage (`Gateway service inspection is unavailable; automatic service
restart was skipped`). So the gateway must be **stopped before** the update
runs — and stopping it ends your own session. An inline `sudo systemctl stop`
would also deadlock (ADR 0005).

The solution is **one detached chain**: the whole sequence runs in a
`setsid` process that survives your session, so the update completes while you
are gone. You launch it, your session drops, the gateway comes back on the new
release, and you verify in a new turn. This is the sanctioned agent path.

## Hard rules

- **Never open, query, copy, or inspect OpenClaw's SQLite databases.** No
  `sqlite3`, no file copies, no lock hunting. `openclaw update status` is the
  only source of truth you need.
- **Never run a blocking `systemctl stop/restart` in your own turn.** Only the
  detached chain below touches service state.
- **No extra flags:** the update command is exactly `openclaw update --yes`.
  Never `--no-restart`, `--tag`, or channel overrides for a routine update.
- **No polling loops** (`sleep N; openclaw update status`): they keep agent
  turns active and are pointless here — your session ends anyway.
- The watchdog guard `~/.openclaw/.maintenance` must exist while the chain
  runs; the chain removes it at the very end.

## Step 1 — Preflight (read-only, CLI only)

```bash
systemctl is-active openclaw-gateway.service
curl --fail --silent --output /dev/null http://127.0.0.1:18789/ && echo "HTTP OK"
openclaw --version
openclaw update status
pgrep -af openclaw-update || echo "no updater running"
```

If an updater process is alive, **stop and report** — do not launch the chain.
A previously *failed* run is fine; the chain replaces it.

## Step 2 — Pause the watchdog

```bash
touch ~/.openclaw/.maintenance
```

## Step 3 — Launch the detached update chain

Run this exactly as written. Absolute paths are used so it cannot depend on
your shell environment:

```bash
LOG=/home/shelldon/.openclaw/logs/update-run-$(date +%Y%m%dT%H%M%S).log
setsid /bin/bash -c '
  /usr/bin/sudo -n /usr/bin/systemctl stop openclaw-gateway.service
  until [ "$(/usr/bin/systemctl is-active openclaw-gateway.service)" = "inactive" ]; do sleep 5; done
  /home/shelldon/.npm-global/bin/openclaw update --yes
  /home/shelldon/.npm-global/bin/openclaw doctor --fix --non-interactive
  /usr/bin/sudo -n /usr/bin/systemctl start openclaw-gateway.service
  until /usr/bin/curl --fail --silent --output /dev/null http://127.0.0.1:18789/; do sleep 5; done
  rm -f /home/shelldon/.openclaw/.maintenance
' >"$LOG" 2>&1 </dev/null &
echo "update chain launched detached; log=$LOG"
```

The chain always ends by starting the gateway and re-arming the watchdog, even
if the update fails. Expect roughly 15-20 minutes.

Then **tell the user** in one or two lines: the gateway is going down now, it
will come back on the new release in about 15-20 minutes, the log is at
`$LOG`, and this session will drop. Then **end your turn.** Do not poll, do not
re-run anything.

## Step 4 — Verify (new turn, once the gateway is back)

```bash
openclaw --version
openclaw update status
systemctl is-active openclaw-gateway.service
curl --fail --silent --output /dev/null http://127.0.0.1:18789/ && echo "HTTP OK"
journalctl -u openclaw-gateway.service --since "-20 min" | grep "http server listening"
ls -l ~/.openclaw/.maintenance 2>&1
```

If the version did **not** change, report `openclaw update status` verbatim and
stop — do not retry, do not improvise, do not start inspecting databases.

If the guard is somehow still present after a successful start, remove it:

```bash
rm -f ~/.openclaw/.maintenance
```

## Report

- Version before → after
- Update outcome (`openclaw update status`)
- Service, HTTP, and plugin verification results
- Guard removed: yes/no
- Anything unresolved, with the exact next command
