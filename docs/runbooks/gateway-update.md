# Gateway Update Runbook

How to update the Shelldon OpenClaw gateway. Governance: ADR 0004 (system
unit), ADR 0005 (self-restart, watchdog, tmp lifecycle). Upstream reference:
`install/updating.md` (append `.md` per the repo URL rule).

Complete one maintenance window in this order: **stop → update → rebuild/install
stale local plugins → final Doctor → start → verify → re-arm watchdog**.
Version output alone is not completion; the Vault Access Broker and public UI
must work too.

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
   access is exactly the contention that fails activation. Use official docs
   and CLI reports; routine updates do not require inspecting or patching
   installed OpenClaw source.
2. **Never stop or restart the gateway from an agent turn — any mechanism.** Forbidden in-turn triggers: `sudo systemctl stop/restart`, `openclaw gateway restart` in ANY form (plain, `--safe`, `--force`, `--wait`, `--skip-deferral`), `SIGUSR2` / `kill -USR2` / `gateway.restart.safe` (in-process restart, same PID — this is what `--safe` does on core ≥ `2026.9.6`), any gateway restart tool/API call, and any Control UI restart button. Background: an in-turn `sudo systemctl stop/restart` deadlocks against the gateway's shutdown drain until the stop timeout SIGKILLs everything (ADR 0005); an in-process `SIGUSR2` restart bypasses systemd entirely and drops all sessions with ~90s outage (incident 2026-09-24 13:24 CEST — the turn claimed the "approved detached path" in plan text but sent SIGUSR2, PID unchanged). The ONLY agent restart paths are `~/.local/bin/openclaw-gateway-restart-detached` and the `setsid` update chain below. Service control otherwise happens in the operator's terminal. Verification is a PID change plus the systemd journal — plan prose proves nothing.
3. **No extra flags.** Run `openclaw update --yes`. Do not add `--no-restart`,
   `--tag`, or channel overrides for a routine update.
4. **Pause the watchdog** for the whole window:
   `touch ~/.openclaw/.maintenance` (alias `.maintainance` honored). Remove it
   only after verification — a guard left behind means an unguarded dead
   gateway later.
5. **`openclaw doctor --fix --non-interactive` only with the gateway stopped.**
   A running gateway holds the state lease; `--non-interactive` removes prompts,
   not locks. The same stopped-gateway requirement applies to `update repair`
   when it runs maintenance. While online, use `doctor --lint --non-interactive`.
6. **The update window needs a detached chain.** Stopping the gateway ends
   any agent session hosted by it, so an agent cannot run the sequence inline.
   The sanctioned agent path is one `setsid` chain that runs
   stop → update → local-plugin rebuild → final Doctor → start → verify →
   re-arm the watchdog. Arrange an exit trap that attempts to start the gateway
   even if an earlier step fails; recovery is not update success. A human at an
   independent SSH terminal may run the sequence in the foreground instead.
   An external Pi session is not a gateway-hosted turn; establish the actual
   execution context rather than assuming stopping OpenClaw ends that session.

## Keep calm during long steps

This is a weak/resource-constrained host sharing 8 GB RAM with other services.
Budget generously: the 2026.9.7 update took about 31 minutes and a separate
full Doctor took about 18 minutes. These are observations, not deadlines or
proof that hardware explains every delay. Plugin rebuilds add time.

**Keep calm while progress continues.** Do not add a 10–15-minute shell timeout,
press Ctrl-C merely because a step is slow, launch a second Doctor, or repeat
repair to chase historical warnings. Configure the execution harness to allow
long steps. Check process existence, log timestamps/recent redacted lines, and
host resources when needed; continued activity is progress, not completion.
Avoid ten-minute blocking `tail --pid` waits that leave the owner uninformed.
Give brief progress updates without polling OpenClaw state in a tight loop.

`[sqlite/transaction] slow …` reports a duration threshold exceeded, not by
itself corruption. A nonzero exit, skipped migration, or lost maintenance lease
needs investigation. Wait for **`Doctor complete` and exit 0** before accepting
the final Doctor run; an interrupted/killed run does not qualify.

## Procedure — agent path (detached chain)

One `setsid` chain so it survives the gateway stopping. Absolute paths keep it
independent of the launching shell. This is a **template**: insert the planned
local-plugin rebuild/install commands at the marked point before launching it;
for this host, the Vault Access Broker rebuild is mandatory on a core bump:

```bash
LOG=/home/shelldon/.openclaw/logs/update-run-$(date +%Y%m%dT%H%M%S).log
setsid /bin/bash -c '
  cd /home/shelldon || exit 1
  trap '\''/usr/bin/sudo -n /usr/bin/systemctl start openclaw-gateway.service'\'' EXIT
  touch /home/shelldon/.openclaw/.maintenance
  /usr/bin/sudo -n /usr/bin/systemctl stop openclaw-gateway.service || exit 1
  [ "$(/usr/bin/systemctl is-active openclaw-gateway.service)" = "inactive" ] || exit 1
  /home/shelldon/.npm-global/bin/openclaw update --yes || exit 1
  # INSERT planned local-plugin rebuild/install commands here (steps 1–3 below).
  /home/shelldon/.npm-global/bin/openclaw doctor --fix --non-interactive || exit 1
  /usr/bin/sudo -n /usr/bin/systemctl start openclaw-gateway.service || exit 1
  until /usr/bin/curl --fail --silent --output /dev/null http://127.0.0.1:18789/; do sleep 5; done
  echo "Local HTTP ready; public UI, channels and Vault verification still required"
' >"$LOG" 2>&1 </dev/null &
```

The exit trap attempts service recovery after failure; it cannot guarantee
startup succeeds. Keep the maintenance guard until the verification checklist
passes, then remove it and confirm the watchdog is armed. If the chain fails,
restore service availability and investigate the reported phase; do not call
that a completed update. Do not poll it in a loop.

## Procedure — human path (foreground, SSH terminal)

```bash
# 1. Use the owning account/cwd, pause the watchdog, arrange service recovery.
cd /home/shelldon
trap 'sudo -n systemctl start openclaw-gateway.service' EXIT
touch ~/.openclaw/.maintenance

# 2. Stop the gateway and wait for inactive.
sudo systemctl stop openclaw-gateway.service
until [ "$(systemctl is-active openclaw-gateway.service)" = "inactive" ]; do sleep 5; done

# 3. Confirm the ground is clear (CLI + process view only).
# If another updater/Doctor is running, wait for it; do not launch a competitor.
pgrep -af 'openclaw.*(update|doctor)' || true
openclaw update status          # repair an actual unfinished run while stopped

# 4. Update. Allow long execution; no short wrapper timeout.
openclaw update --yes           # on failure, follow its recovery advice first

# 4a. Rebuild/test/install stale local plugins NOW, while still stopped.
# Follow steps 1–3 under "Local plugins and version bumps" below.
# This includes Vault; do not postpone it until after bringing the gateway up.

# 5. Run one explicit final Doctor AFTER plugins are rebuilt.
# Wait for Doctor complete AND exit 0, even if it takes tens of minutes.
openclaw doctor --fix --non-interactive
# A failure is not permission to continue normal activation; recover service
# and investigate. Do not repeatedly rerun Doctor after a successful pass.

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

1. Bump **all five** version pins in the source
   (`~/.openclaw/plugins/<id>/package.json`) to the new core version:
   `openclaw.compat.pluginApi`, `openclaw.build.openclawVersion`,
   `openclaw.build.pluginSdkVersion`, `peerDependencies.openclaw`, **and
   `devDependencies.openclaw`**. Missing the dev dependency is the subtle one:
   the build then resolves the *stale local SDK*, and the plugin refuses the
   state directory (`schema 18 vs 17`) even though the manifest looks correct.
2. Refresh dependencies and rebuild, using the plugin's own scripts
   (`scripts` in that package.json; for the Vault Access Broker:
   `pnpm install`, `npm run plugin:build`, `npm run plugin:validate`).
   **pnpm workspace note:** the source's `pnpm-workspace.yaml` must set
   `allowBuilds: true` for the packages that need build scripts (for the Vault
   Access Broker: `@google/genai`, `esbuild`, `koffi`, `openclaw`, `protobufjs`,
   `tree-sitter-bash`). Placeholder/prompt values fail the install with
   `ERR_PNPM_IGNORED_BUILDS`. A freshly published core release is also blocked by
   pnpm's minimum-release-age gate; add the new version to
   `minimumReleaseAgeExclude` in the same file (for the Vault Access Broker:
   `openclaw@<version>` and `@openclaw/ai@<version>`).
3. Install a **lean copy**, never the development source tree. Installing the
   source directory copies the whole tree and blows the installer's hardlink
   preflight:

   ```
   failed to copy plugin: FsSafeError: Source hardlink preflight exceeds 50000 entries
   ```

   (A development `node_modules` is ~71k entries / ~1 GB. On such a failure the
   installer rolls the previous copy back intact — no damage.)

   **Verified route — stage a lean copy:**

   ```bash
   rm -rf /tmp/vab-install && mkdir -p /tmp/vab-install
   cd ~/.openclaw/plugins/<id>
   cp -a dist openclaw.plugin.json README.md package.json /tmp/vab-install/
   cd /tmp/vab-install
   npm install --omit=dev                      # production deps only (~1.5k entries)
   ln -sfn /home/shelldon/.npm-global/lib/node_modules/openclaw node_modules/openclaw
   openclaw plugins install /tmp/vab-install --force
   ```

   The installer preserves the `node_modules/openclaw` symlink and the version
   declarations. Clean the staging directory up afterwards.

   **Alternative — packed artifact:** `npm run plugin:build`, `npm pack`, then
   `openclaw plugins install ./<name>-<version>.tgz --force`. The source's
   `files` field (`dist`, `openclaw.plugin.json`, `README.md`) keeps this to a
   few KB.
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
- `openclaw update status` reports the current update terminal (`succeeded`).
  Also inspect phase outcomes: `update repair` can exit 0 with maintenance
  skipped or pending. That is not a completed Doctor run.
- The explicit final `doctor --fix --non-interactive` logged `Doctor complete`,
  exited 0, and did not leave required migrations or local-plugin repairs
  skipped. Record its outcome before restarting; do not restart a second full
  Doctor just to verify the first one.
- **Local plugin check reports `OK` for every path-installed plugin** (see the
  section above), and `openclaw doctor` shows no plugin ERROR for them.
- Every expected plugin appears in the gateway's plugin list, including
  `vault-access-broker` when the Vault Access Broker is meant to be online.
- Control UI loads via `https://ai.sieh.org/` in a real browser; a successful
  local HTTP probe or `/healthz` is not sufficient. Verify the public `/`
  response is HTTP 200 **and HTML containing
  `data-openclaw-control-ui-build-id`**, then confirm the application renders
  and the existing owner connection works. A JSON
  `proxy_attribution_required` response is a failed update verification.
- If public attribution fails, compare the exact peer in the gateway's
  `observed unattributable proxy-shaped traffic from …` log with
  `gateway.trustedProxies`. Verify that peer serves the configured NPM host
  before correcting its single-IP entry. This does not establish that an
  operator changed Nginx; do not change proxy settings or trust a subnet
  merely to suppress the error.
- `openclaw status --deep --json` reports Discord/Telegram connected, ready,
  and without a last error; do not send unsolicited channel messages.
- Verify the Vault Access Broker through the live Gateway (`plugins.inspect`,
  `tools.catalog` for Shelldon), the optional tool and both typed hooks via
  runtime inspection, and its controlled fake-CLI tests. Keep Retrieval
  Approval and redaction in place. Maintenance is not permission to retrieve
  an arbitrary Vault Item.
- Measure generated plugin/runtime and compile caches before and after the
  window (`du -sk` over all paths in one invocation, so shared hardlinks are
  counted once). Existing boot cleanup remains responsible for temporary
  captures. Remove obsolete, regenerable unnamespaced Node compile caches
  only with the gateway stopped; preserve the current version-namespaced
  cache. Never delete an active capture, npm runtime generation, or recovery
  archive just to meet a disk target.
- Guard file gone; `systemctl --user list-timers | grep openclaw` shows the
  watchdog armed.
- The boot wiped `~/.openclaw/tmp` and `/tmp/openclaw-plugin-build-*`
  (ExecStartPre hook), so post-update debris self-cleans.

## Failure branches

- **`doctor-failed` / `agent-database-lease-active`:** the gateway was still
  running. It holds the agent-database leases. Stop it and re-run step 4.
  The run rolls back on its own; the live release is untouched.
- **Actual unfinished run or required post-update repair:** with the gateway
  stopped and no other maintenance process running, use
  `openclaw update repair --yes`. Inspect completed/skipped phases, not only
  its exit code; then resume at the unfinished step rather than repeating the
  entire update.
- **Historical abandoned record with no target build:** repair may leave it
  abandoned because version equality cannot prove that old attempt succeeded.
  Distinguish it from an active run and current failures. Record the remaining
  notice honestly; do not erase history, fabricate success, or repeat repair
  indefinitely to make it disappear.
- **Doctor exit 137 / SIGINT / lost maintenance lease after interruption:** the
  run did not complete. The exit alone does not establish corruption or the
  precise kill source. Wait until its processes are gone, then perform one
  supported stopped-gateway run without a short artificial deadline.
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
