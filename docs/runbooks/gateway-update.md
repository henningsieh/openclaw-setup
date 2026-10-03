# Gateway Update Runbook

Governance: ADR 0004 (system unit), ADR 0005 (detached service control, watchdog,
boot temp cleanup). Upstream: https://docs.openclaw.ai/install/updating.md.

The supported entry point is the tracked **`scripts/gateway-update.sh`**. It
owns one maintenance window:

**stop → update → broker rebuild/test/install → final Doctor → start → automatic
verification → owner UI confirmation → remove owned guard / watchdog recovery**.

An installed version or recovered service alone is not a completed update.

## Routine procedure

Run as the native gateway owner from the setup repository. The entry point uses
Bash and Python 3's standard library; no additional Python packages are needed.
It discovers the owning home, repository and executables. Deliberate host
settings (system unit, watchdog, public/local URLs) live together in `Host` in
`scripts/gateway_update.py`; this is a native-host procedure, not a fleet updater.
No release number is embedded in the workflow.

### 1. Prepare

Read the target release notes, this runbook and ADR 0005. Establish the execution
context: an external Pi session survives gateway downtime; a gateway-hosted
agent turn does not. Run:

```bash
scripts/gateway-update.sh plan
```

`plan` is read-only: no service changes, guard creation, dependency installs or
run directories. It checks the owning context, another OpenClaw CLI/updater/
Doctor, existing guards, active service/watchdog, sudo permission listing, disk
space, installed and configured-channel versions, local plugin inventory,
previous boot plugin list when readable, and cache sizes. It does not read
credentials or OpenClaw databases. A 5 GiB free-space floor is a conservative
initial check, not an estimate; the updater owns its capacity preflight.

Resolve a refusal before proceeding. Unknown local plugin sources are refused
rather than silently omitted; add a tested rebuild to the workflow first.
`start` repeats preflight under a lifecycle lock so a stale plan is not authority.

### 2. Start one window

```bash
scripts/gateway-update.sh start --expect-version <target-release>
```

`--expect-version` is optional but recommended. It validates the candidate on
the **configured channel** before downtime and the installed version afterward.
It is not a pin, does not pass `--tag`, and never overrides the update channel.
The core command remains exactly **`openclaw update --yes`**. No available
update means refusal without downtime, not another Doctor window.

`start` returns the run id, worker PID and log path. It creates a unique private
run directory under the gitignored `logs/gateway-updates/`, creates `.maintenance`
exclusively with that run's identity, and launches a detached session using
`start_new_session=True` (the native `setsid` mechanism). The lifecycle lock is
inherited by the worker and retained through maintenance. It attempts service
recovery on failure; **recovery is not update success**. Failed windows retain
their guard and exact failed phase for investigation.

The wrapper is persisted in Git. The old `logs/update-2026.9.8.sh` is historical
runtime evidence, not the next update's entry point.

### 3. Monitor through startup

```bash
scripts/gateway-update.sh status
# Read the reported run.log path for the current command's progress/errors.
```

`status` reads private receipts and the lifecycle lock; it does **not** invoke
OpenClaw or compete for maintenance state. It reports current phase, phase and
total elapsed seconds, completed phase timings, log modification time, guard
ownership, and whether an operation holds the lock. A missing worker without a
terminal receipt is an attention condition, not success. Revisit at reasonable
intervals and keep the owner informed; do not repeatedly run Doctor/repair or
poll OpenClaw state in a tight loop.

Maintenance commands have **no short wrapper timeout**. The bounded readiness
window after startup is separate: local HTTP and then live Gateway/plugin/channel
readiness, up to ten minutes, with spaced read-only health probes. It does not
retry maintenance. Continued process/CPU
activity is evidence of activity, not proof of semantic progress or completion.
A quiet log does not by itself prove a hang; an explicit failed phase does need
investigation. Do not interrupt a slow Doctor merely to meet an estimate.

**Do not promise a completion time.** The 2026.9.8 window observed roughly
56 minutes for core update, seven for broker rebuild/install, twenty for final
Doctor, and two for startup. Earlier 2026.9.7 observations were about 31 minutes
for update and 18 for a separate Doctor. These are observations, not deadlines
or proof that hardware explains every delay.

An external Pi operator must stay with the update through startup and verification.
A gateway-hosted turn will drop; resume monitoring in an independent session or
new turn. Detachment is recovery protection, not permission to abandon monitoring.

### 4. Complete owner verification and finish

Automatic checks produce **`awaiting-confirmation`**, not `complete`:

- installed and live version agree; this window's recorded core update run
  is the current terminal `succeeded` run;
- final stopped-gateway Doctor logged `Doctor complete`, exited 0, and left no
  explicit plugin ERROR or unfinished migration report;
- system service active with a different PID, local HTTP success;
- public `/` is successful HTML with the current
  `data-openclaw-control-ui-build-id`, not JSON `proxy_attribution_required`;
- Discord and Telegram connected, ready, with no last error;
- live Gateway plugin set includes codex and the Vault Access Broker, without
  plugin errors/unavailability, and preserves the previous boot's list when
  that list was readable;
- all installed extension API declarations cover the core (the tested exact
  and `>=` forms; unknown ranges fail closed);
- live `plugins.inspect` and Shelldon's `tools.catalog` expose the broker;
  runtime inspection reports loaded/enabled/activated, built on the current
  SDK, optional `vault_fetch`, `before_tool_call` and `tool_result_persist`,
  and no diagnostics;
- startup journal has the plugin listener and non-secret Vault runtime health
  lines when accessible; owned boot-cleanup targets captured immediately before
  start no longer retain their old file identity (metadata only, no contents);
- cache sizes captured before and after using a single `du -sk` invocation per
  measurement so shared hardlinks are counted once.

Then verify public application **rendering in a real browser** and the owner's
existing signed-in connection. Prefer the native browser tool for agent checks.
A fresh browser may show the token login screen: normal rendering evidence,
**not** proof of the existing owner connection or an authentication failure.
Do not retrieve a token, inspect secret environment files, or change auth to
connect that browser. Ask the owner to confirm their existing connection.

After both rendering and owner connection checks pass:

```bash
scripts/gateway-update.sh finish --owner-ui-confirmed
scripts/gateway-update.sh status
```

`finish` refreshes the read-only runtime checks, verifies watchdog activation,
removes **only the latest successful run's own guard**, then confirms the timer
remains active. A replaced guard, alias guard, failed/active run, or failing
verification blocks cleanup. A completed finish is idempotent and still refuses
to remove a newer guard. Runtime guards and run artifacts remain gitignored.

If journal access was unavailable, have the owner inspect the journal since the
receipt's `startRequestedAt`: require `http server listening` (the expected
plugin list) and `vault-access-runtime healthy: … credentials=3`. Only after
that independent confirmation may finish use the additional flag:

```bash
scripts/gateway-update.sh finish --owner-ui-confirmed --journal-confirmed
```

This is owner attestation of a performed journal check, not a skip switch.
Do not call the update complete while either owner check remains pending. The
watchdog timer can be active while **recovery is paused by the guard**; report
that distinction explicitly. Do not leave a successful window awaiting cleanup
without telling the owner what is needed.

## Local plugin maintenance

The workflow rebuilds the **Vault Access Broker** from
`plugins/vault-access-broker/` after the new core is installed and while the
service is stopped. It updates all five pins: compatibility API, build core,
build SDK, peer dependency, and development dependency. Omitting the last pin
can resolve a stale SDK even when the manifest looks current.

It checks explicit `allowBuilds: true` entries in `pnpm-workspace.yaml` for
`@google/genai`, `esbuild`, `koffi`, `openclaw`, `protobufjs`, and
`tree-sitter-bash`, and adds only the new `openclaw@<version>` and
`@openclaw/ai@<version>` release-age exclusions. It runs `pnpm install`,
`npm test`, `npm run plugin:build`, and `npm run plugin:validate`.

Tests use a **controlled fake Bitwarden CLI**, never the Personal Vault Identity.
A core bump is not permission to fetch a real Vault Item, create a disposable
Vault Item, invoke the private CLI, or run the separate owner-approved login test
in [vault-access-runtime.md](vault-access-runtime.md). Preserve Retrieval Approval
and redaction.

Installation uses a unique lean staging directory containing only `dist`, the
manifest, README and package metadata. Production dependencies are installed
without automatically installing the core peer; that peer is symlinked to the
new core root reported by the CLI. The managed install uses `--force` and the
existing explicit local capability acceptance. The staging directory is cleaned
on normal/error exit. Installing the development tree instead can exceed the
50,000-entry hardlink preflight; do not use it as a shortcut.

Registry-managed **llama-cpp** is not rebuilt by hand. Its `>=` API range allows
it to load while waiting for upstream's matching release. An older registry
version alone is not update failure.

## Safety and failure branches

- Service control from agent turns goes only through the tracked detached update
  entry point or `~/.local/bin/openclaw-gateway-restart-detached` for ordinary
  restarts. Inline `systemctl stop/restart`, in-process restart signals,
  `openclaw gateway restart` variants, and restart tools/UI controls remain
  forbidden (ADR 0005).
- Never open, query, copy, or inspect OpenClaw's SQLite databases, patch installed
  core source, expose credentials, or change credential permissions during an
  update. Use supported CLI reports, process inspection and service journal.
- `doctor --fix --non-interactive` and maintenance-running `update repair`
  require a stopped gateway. Online checks use `doctor --lint --non-interactive`.
  Non-interactive mode does not remove leases.
- A `failed` receipt preserves the guard and records the failure phase. The
  worker attempts to start the service if it had requested a stop; a pre-stop
  refusal never starts a service against another operator's maintenance. Check
  `recoveryStartAttempted` and `recoveryStartExit`,
  service state and journal. Do not launch a competing window or manually delete
  its guard to fabricate completion.
- Actual unfinished updates follow current CLI recovery advice: with the service
  stopped and no maintenance competitor, `openclaw update repair --yes`, inspect
  completed/skipped phases, then resume required plugin maintenance/final Doctor.
  This is a deliberate independent-terminal recovery operation, not an automatic
  retry inside the reusable script. Reconcile the failed window's guard explicitly
  after recovery and full verification; `finish` deliberately refuses failed runs.
- An old abandoned record or update-time maintenance notice does not justify
  extra repair/Doctor runs merely to erase warnings. Service-inspection warnings
  are expected for this system-scope unit. Denied access to the Vault environment
  file is not permission to inspect bootstrap credentials.
- `agent-database-lease-active` means the gateway/another process still holds
  state; inspect processes and service state, not databases. Exit 137, interruption,
  or lost lease is not a successful Doctor and does not establish corruption.
- If public attribution fails, compare the exact logged proxy peer with the
  configured trusted proxies and verify it serves this NPM host before changing
  a single-IP entry. Do not trust a subnet or change proxy/auth settings to
  suppress verification errors.
- Boot cleanup remains the existing `ExecStartPre` hook (ADR 0005). It wipes
  gateway temporary captures; new captures may already exist after startup.
  Do not delete active captures, npm generations, recovery archives or the
  current namespaced compile cache to meet a disk target. The script measures
  caches but intentionally performs no new cache-deletion policy.

## Testing and repository follow-up

```bash
bash -n scripts/gateway-update.sh
python3 -m unittest discover -s tests -v
# Equivalent: pnpm run test:gateway-update
```

The tests inject fake command execution; no service, network, OpenClaw database
or real Vault credentials are used. Cover guard ownership, overlap refusal,
version checks, dependency pins, ordering, recovery, incomplete Doctor,
registration/health checks, and confirmed cleanup. Do not live-test `start` or
`finish` as part of a source refactor.

After a real update, sync version anchors and review the tracked config snapshots,
broker pins/lockfile/workspace exceptions, and redacted upstream update report.
Inspect Git status and the staged diff before committing; private lifecycle logs
and guards are not repository content.
