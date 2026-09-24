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
pgrep -x openclaw-update || echo "no updater running"
```

Also inventory the **path-installed local plugins** — a core bump silently
skips any that are pinned to the old plugin API, and the update is not complete
until they are rebuilt (see the runbook section "Local plugins and version
bumps" for the exact script):

```bash
CORE=$(python3 -c "import json;print(json.load(open('/home/shelldon/.npm-global/lib/node_modules/openclaw/package.json'))['version'])")
python3 - "$CORE" <<'PY'
import json, glob, os, re, sys
core = sys.argv[1]
def tup(v): return tuple(int(x) for x in re.findall(r'\d+', v))
def ok(decl):
    if not decl: return False
    decl = decl.strip()
    for op in ('>=', '<=', '>', '<', '^', '~'):
        if decl.startswith(op):
            v = decl[len(op):].strip()
            return tup(core) >= tup(v) if op in ('>=', '^', '~') else tup(core) <= tup(v)
    return decl == core
for p in sorted(glob.glob(os.path.expanduser('~/.openclaw/extensions/*/package.json'))):
    d = json.load(open(p)); oc = d.get('openclaw') or {}
    api = ((oc.get('compat') or {}).get('pluginApi')
           or (oc.get('build') or {}).get('openclawVersion')
           or (d.get('peerDependencies') or {}).get('openclaw'))
    name = d.get('name') or os.path.basename(os.path.dirname(p))
    print(f"{'OK   ' if ok(api) else 'STALE'} {name}: declares {api}, host {core}")
PY
```

Record the result. Any `STALE` local plugin must be rebuilt in Step 4 — the
updater cannot do it, because a rebuild needs the new core installed first.

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

Then handle local plugins — **this is part of completing the update**:

1. Rerun the preflight local-plugin check above.
2. For each `STALE` **local** plugin (e.g. `vault-access-broker`), rebuild it:
   bump **all five** version pins in `~/.openclaw/plugins/<id>/package.json` to
   the new core version: `openclaw.compat.pluginApi`,
   `openclaw.build.openclawVersion`, `openclaw.build.pluginSdkVersion`,
   `peerDependencies.openclaw`, **and `devDependencies.openclaw`** (missing the
   dev dependency makes the build resolve the stale local SDK and refuse the
   state dir: `schema 18 vs 17`). Ensure `pnpm-workspace.yaml` sets
   `allowBuilds: true` for the packages needing build scripts, or
   `pnpm install` fails with `ERR_PNPM_IGNORED_BUILDS`. Then rebuild with the
   plugin's own scripts (`pnpm install`, `npm run plugin:build`,
   `npm run plugin:validate`).
   Then **install a lean copy — never the development source tree**, which fails
   with `FsSafeError: Source hardlink preflight exceeds 50000 entries` (~71k
   entries / ~1 GB). Stage one and install that (the installer preserves the
   symlink; a failed install rolls the previous copy back intact):
   `cp -a dist openclaw.plugin.json README.md package.json /tmp/<id>-install/`,
   `npm install --omit=dev` there,
   `ln -sfn /home/shelldon/.npm-global/lib/node_modules/openclaw node_modules/openclaw`,
   then `openclaw plugins install /tmp/<id>-install --force`, and delete the
   staging directory afterwards.
3. Restart the gateway with `~/.local/bin/openclaw-gateway-restart-detached`
   (never a blocking `systemctl` in your turn).
4. Confirm the plugin is back in the `http server listening (N plugins: …)` line
   from `journalctl -u openclaw-gateway.service --since "-5 min"`.

Official plugins that declare a `>=` range (e.g. `llama-cpp`) are **not**
rebuilt — they wait for upstream's release and load normally.

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
