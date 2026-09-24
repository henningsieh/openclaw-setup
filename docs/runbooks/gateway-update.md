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
6. **The update window needs a detached chain.** Stopping the gateway ends
   any agent session hosted by it, so an agent cannot run the sequence inline.
   The sanctioned agent path is one `setsid` chain that runs
   stop → update → doctor → start → wait-for-HTTP → re-arm the watchdog. It
   survives the gateway stopping, and it always ends by starting the gateway
   again, even when the update fails. A human at an SSH terminal may run the
   same sequence in the foreground instead.

## Procedure — agent path (detached chain)

One `setsid` chain so it survives the gateway stopping. Absolute paths keep it
independent of the launching shell:

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
```

Invariants: the chain always ends by starting the gateway and re-arming the
watchdog, even if the update fails; verify afterwards with the checklist below.
Do not poll it in a loop.

## Procedure — human path (foreground, SSH terminal)

```bash
# 1. Pause the watchdog.
touch ~/.openclaw/.maintenance

# 2. Stop the gateway and wait for inactive.
sudo systemctl stop openclaw-gateway.service
until [ "$(systemctl is-active openclaw-gateway.service)" = "inactive" ]; do sleep 5; done

# 3. Confirm the ground is clear (CLI + process view only).
openclaw update status          # an unfinished run here => run `openclaw update repair --yes` first
pgrep -x openclaw-update || echo "no updater running"

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

## Local plugins and version bumps (mandatory check)

Path-installed plugins (`~/.openclaw/extensions/*`, or entries in
`plugins.load.paths`) declare the plugin API they were built against
(`openclaw.compat.pluginApi` in their `package.json`). On a core version bump
the host **skips** any plugin whose declaration does not cover the new
version:

```
plugin requires plugin API 2026.9.5, but this host is 2026.9.6; skipping discovery
```

Doctor then reports `Plugin install incomplete: plugin metadata is missing`.
**No updater can fix this.** Upstream treats path-installed copies as
operator-managed, and the plugin must be rebuilt against the new SDK — which is
only possible *after* the new core is installed. A core update is therefore not
"complete" until every local plugin passes this check.

**Pre-update (inventory, read-only).** Record which local plugins exist and
what they declare, so the rebuild is planned for the same window:

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

**Post-update (mandatory).** Rerun the same check. For every `STALE` **local**
plugin:

1. Bump the declaration in the source (`~/.openclaw/plugins/<id>/package.json`):
   `openclaw.compat.pluginApi`, `openclaw.build.openclawVersion`,
   `openclaw.build.pluginSdkVersion`, and `peerDependencies.openclaw` to the new
   core version.
2. Rebuild from the plugin's own scripts — check that package.json's `scripts`
   (for the Vault Access Broker: `npm run plugin:build`, `npm run plugin:validate`).
3. Regenerate metadata and install from a **packed artifact, not the source
tree**: `npm run plugin:build` (which runs `tsc` plus `openclaw plugins build
   --entry ./dist/index.js` — this is what creates the metadata doctor reports
   as missing), then `npm pack`, then install the resulting `.tgz`.
   Installing the plugin **directory** instead makes the installer copy the
   whole tree, and a development `node_modules` blows its hardlink preflight:

   ```
   failed to copy plugin: FsSafeError: Source hardlink preflight exceeds 50000 entries
   ```

   The source's `files` field defines the shippable subset, so the artifact is
   tiny (a few KB) while the source tree can hold tens of thousands of entries.
   If the directory must be installed, prune dev dependencies first
   (`pnpm install --prod`, or `npm prune --omit=dev`) so the tree stays under
   the preflight limit.

   ```bash
   cd ~/.openclaw/plugins/<id>
   npm run plugin:build     # tsc + `openclaw plugins build --entry ./dist/index.js`
   npm pack                 # artifact contains only the `files` entries
   openclaw plugins install ./<name>-<version>.tgz --force
   ```
4. Restart the gateway (agent: the detached wrapper; human: `sudo systemctl
   restart`) and confirm the plugin appears in the `http server listening
   (N plugins: …)` line.

**Known local plugin:** `vault-access-broker` — source
`~/.openclaw/plugins/vault-access-broker/`, installed copy
`~/.openclaw/extensions/vault-access-broker/`. It must be rebuilt on **every**
core version bump, otherwise the Vault Access Broker is offline and
`vault_fetch` is unavailable to Shelldon.

**Not a local plugin:** `llama-cpp` is an official/ClawHub plugin that declares
`>=` a range and loads normally; it only waits for upstream's release. Do not
rebuild it by hand.

## Verification checklist

- `openclaw --version` shows the target release.
- Service `active`, HTTP 200 on `127.0.0.1:18789`.
- `openclaw update status` reports the run terminal (`succeeded`).
- **Local plugin check reports `OK` for every path-installed plugin** (see the
  section above), and `openclaw doctor` shows no plugin ERROR for them.
- Every expected plugin appears in the gateway's plugin list, including
  `vault-access-broker` when the Vault Access Broker is meant to be online.
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
- **`failed to copy plugin: FsSafeError: Source hardlink preflight exceeds
  50000 entries`:** the plugin was installed from a source tree carrying a
  development `node_modules`. Install the packed artifact instead, or prune dev
  dependencies first (see "Local plugins and version bumps").
- **Plugin skipped / `Plugin install incomplete: plugin metadata is missing`:**
  a path-installed local plugin is pinned to the old plugin API. Rebuild and
  reinstall it per "Local plugins and version bumps" above, then restart the
  gateway. This is expected work, not a failed update.
- **Failed after the package swap:** package rollback cannot undo migrated
  state. Finish with `openclaw doctor --fix` on the installed build, then
  start the service.
- **Gateway won't start:** `journalctl -u openclaw-gateway.service -n 100`;
  common causes are config errors (doctor flags them) or a full disk
  (`df -h /`).
- **Installation considered unrecoverable:** the updater points at
  `openclaw triage`. Treat that as a human decision, not an automatic step.
