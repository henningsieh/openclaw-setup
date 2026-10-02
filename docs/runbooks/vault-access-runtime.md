# Pinned Vault Access Runtime

The Vault Access Broker uses the official Bitwarden Password Manager CLI
`2026.8.0` from the `cli-v2026.8.0` Bitwarden release. The Vaultwarden URL is
an explicit non-secret startup setting, not a code or unit-file constant.

The gateway is managed by the **system** systemd manager but its process runs
as the unprivileged `shelldon` user. This preserves the native, non-Docker
service identity while allowing `LoadCredentialEncrypted=` to decrypt inputs
on this host's systemd 255; the equivalent per-user service cannot do so.

The runtime is deliberately separate from agent shell paths:

- CLI and state: `/home/shelldon/.local/lib/openclaw/vault-access-broker/`
  (mode `0700`)
- CLI executable: `bin/bw` (mode `0700`, outside the service `PATH`)
- Bitwarden application data: `state/` via `BITWARDENCLI_APPDATA_DIR`
- encrypted credential files:
  `/etc/openclaw/credentials/vault-access-broker/` (root-owned, mode `0700`)
- startup URL configuration: `/etc/openclaw/vault-access-broker.env` (root-owned,
  mode `0600`, loaded by systemd before gateway startup)

Only the gateway service receives the three plaintext inputs. Systemd exposes
them as read-only files below its per-service `$CREDENTIALS_DIRECTORY`; they
are never put in `openclaw.json`, Git, the normal gateway environment, or CLI
arguments.

## Initial installation

Run these commands as `shelldon` from `/home/shelldon/.openclaw`. They download
only the pinned official release and verify its exact reported version. The
health check additionally pins the tested Linux x64 binary digest.

```bash
set -euo pipefail
version=2026.8.0
runtime=/home/shelldon/.local/lib/openclaw/vault-access-broker
archive=$(mktemp -d)
trap 'rm -rf "$archive"' EXIT

install -d -m 700 "$runtime" "$runtime/bin" "$runtime/state"
gh release download "cli-v$version" --repo bitwarden/clients --dir "$archive" \
  --pattern "bw-linux-$version.zip"
unzip -p "$archive/bw-linux-$version.zip" bw >"$runtime/bin/bw"
chmod 700 "$runtime/bin/bw"
[ "$(BITWARDENCLI_APPDATA_DIR="$runtime/state" "$runtime/bin/bw" --version)" = "$version" ]
install -m 700 plugins/vault-access-broker/runtime/vault-access-runtime-health \
  "$runtime/bin/vault-access-runtime-health"
```

## Credential enrollment and service cutover

Install the service unit and enroll the three inputs from a root shell. The
interactive prompts disable terminal echo and pipe each value directly to
`systemd-creds`; values never enter a command line, configuration file, shell
history, or shell variable.

```bash
set -euo pipefail
credentials=/etc/openclaw/credentials/vault-access-broker
install -d -m 700 "$credentials"
install -m 644 \
  /home/shelldon/.openclaw/plugins/vault-access-broker/runtime/openclaw-gateway.system.service \
  /etc/systemd/system/openclaw-gateway.service
install -m 600 \
  /home/shelldon/.openclaw/plugins/vault-access-broker/runtime/vault-access-broker.env.example \
  /etc/openclaw/vault-access-broker.env
editor /etc/openclaw/vault-access-broker.env # set VAULT_ACCESS_BROKER_SERVER_URL=https://vault.apps.sieh.org

systemd-ask-password --echo=no -n "Vault Access API key" \
  | systemd-creds encrypt --name=vault_api_key - "$credentials/vault-api-key.cred"
systemd-ask-password --echo=no -n "Vault Access API client secret" \
  | systemd-creds encrypt --name=vault_api_client_secret - "$credentials/vault-api-client-secret.cred"
systemd-ask-password --echo=no -n "Vault Access master password" \
  | systemd-creds encrypt --name=vault_master_password - "$credentials/vault-master-password.cred"
chmod 600 "$credentials"/*.cred

systemctl --user disable --now openclaw-gateway.service
systemctl daemon-reload
systemctl enable --now openclaw-gateway.service
systemctl status openclaw-gateway.service --no-pager
```

The last commands are an intentional cutover: they stop the user-managed
instance before starting the system-managed instance, so only one gateway binds
port `18789`. If the final start fails, restore service availability with:

```bash
systemctl disable --now openclaw-gateway.service
systemctl --user enable --now openclaw-gateway.service
```

Never use `systemd-creds decrypt`, `cat`, `echo`, command substitution, or a
shell variable to inspect bootstrap material. The encrypted files are runtime
state and must remain untracked.

## Non-secret health check

The gateway's `ExecStartPre` runs the health check in the same service context
that receives the encrypted credentials. It checks only their presence and
nonzero size, a configured absolute HTTPS URL, directory modes, and the exact
CLI version and binary digest; it never reads or prints a credential value.

```bash
systemctl status openclaw-gateway.service --no-pager
curl --fail --silent --output /dev/null http://127.0.0.1:18789/
```

A successful startup journal contains only this non-secret line:

```text
vault-access-runtime healthy: bw=2026.8.0 vaultwarden=https://configured.example credentials=3
```

Confirm the ordinary agent shell path has no `bw` entry:

```bash
PATH=/usr/bin:/home/shelldon/.npm-global/bin:/usr/local/bin:/bin command -v bw
```

This command must produce no output and exit nonzero. Do not invoke the
private absolute CLI path from an agent shell.

## Retrieval freshness

Every approved `vault_fetch` runs `bw sync` after any required login/unlock and
before `bw list items --search`. The commands use the same fetched session and
abort signal. `bw list` searches the local cache, so syncing only at gateway
startup would leave later Vaultwarden edits invisible. Synchronization is
required on every retrieval, including repeated calls for the same Vault Item.

If synchronization fails, retrieval stops without reading stale cached items.
The existing `finally` block still attempts `bw lock` in every outcome. Lookup
selection, login validation, owner approval, and result redaction are unchanged.
See ADR 0002 for the freshness decision.

## Broker activation and tool policy

The Vault Access Broker is installed from the credential-free Local Plugin
Source through OpenClaw's managed plugin lifecycle. The install copies the
source into the managed plugin root and records provenance; it never uses
`--link` or a bare `plugins.load.paths` entry.

```bash
openclaw plugins install ./plugins/vault-access-broker --force --accept-capabilities
openclaw plugins enable vault-access-broker --accept-capabilities
openclaw plugins inspect vault-access-broker --runtime --json
```

The local-path source requires `--force` (non-ClawHub provenance) and
`--accept-capabilities` (local copies never inherit official trust). The
recorded capability acceptance covers exactly one declared tool,
`vault_fetch`, with no channels, providers, hooks, MCP servers, CLI commands,
skills, or dangerous configuration flags. The runtime inspection must report
`status: loaded`, `enabled: true`, `activated: true`, the tool as
`optional: true`, and exactly the `before_tool_call` and
`tool_result_persist` typed hooks.

Shelldon and Kalle Kief are the currently authorized agents. Capability
authorization has one source of truth: each authorized agent's effective,
agent-specific OpenClaw tool policy. Do not add a parallel agent list in the
broker implementation or `approvals.plugin.agentFilter`.

```bash
openclaw config patch --stdin <<'EOF'
{
  agents: {
    entries: {
      shelldon: {
        tools: {
          alsoAllow: ["vault_fetch"]
        }
      },
      "kalle-kief": {
        tools: {
          alsoAllow: ["vault_fetch"]
        }
      }
    }
  }
}
EOF
```

Each explicit entry is load-bearing: the gateway resolves an optional plugin
tool into an agent catalog only when the effective allowlist names the tool
(or its plugin id) for that agent. No other agent entry may carry `vault_fetch`,
the plugin id, or `group:plugins` for this purpose; a future agent receives
access only through its own explicit entry. The broker hook requires one-time
Retrieval Approval on every invocation, regardless of agent, requester,
channel, or session type. Route approvals to the owner rather than relying on
the originating conversation. Omit `agentFilter` so it does not duplicate the
capability ACL:

```json5
{
  approvals: {
    plugin: {
      enabled: true,
      mode: "targets",
      targets: [{ channel: "telegram", to: "<owner-telegram-user-id>" }]
    }
  }
}
```

Denial, timeout, cancellation, or an unavailable approval route fails closed.

For source changes, rebuild and test the tracked distribution, then reinstall
through the managed lifecycle. Source edits alone do not update the installed
copy. Run from `/home/shelldon/.openclaw`:

```bash
(cd plugins/vault-access-broker && npm run build && npm test)
openclaw plugins install ./plugins/vault-access-broker --force --accept-capabilities
openclaw plugins inspect vault-access-broker --runtime --json
```

Inspection must report `status: "loaded"`, `diagnostics: []`, and the stable
install path `/home/shelldon/.openclaw/extensions/vault-access-broker`, not a
`.tmp` directory. Preserve the existing agent, approval, and channel settings.

When no gateway restart is requested, reload the installed broker:

```bash
openclaw plugins reload vault-access-broker --json
openclaw plugins inspect vault-access-broker --runtime --json
curl --fail --silent --output /dev/null http://127.0.0.1:18789/
```

The reload must report `restartRequired: false` with a new generation receipt,
and the gateway health probe must succeed with uninterrupted uptime.

### Gateway restart (ADR 0005)

For an owner-requested gateway restart, use only the detached wrapper. Record
the current PID and request time before invoking it. Check both
`~/.openclaw/.maintenance` and its `.maintainance` alias: they disable watchdog
recovery, not the wrapper. Preserve a pre-existing guard unless the owner has
authorized ending that maintenance; remove only a guard created for your own
completed maintenance. An ordinary restart needs no new guard, because the
watchdog already skips transitions in flight.

```bash
systemctl show openclaw-gateway.service -p MainPID
date --iso-8601=seconds
~/.local/bin/openclaw-gateway-restart-detached
```

The requesting OpenClaw turn may drop. Verify recovery in a new turn: the PID
must differ, the unit must be active/running, and the startup journal since the
recorded request time must contain the non-secret runtime health line.

```bash
systemctl show openclaw-gateway.service -p MainPID -p ActiveState -p SubState
sudo journalctl -u openclaw-gateway.service --since '<restart request time>' \
  --grep 'vault-access-runtime healthy: bw=2026\.8\.0 .* credentials=3' --no-pager
curl --fail --silent --output /dev/null http://127.0.0.1:18789/
```

Neither an issued wrapper message nor an HTTP response alone proves restart:
require the new PID and the fresh journal line. Keep watchdog recovery enabled
after completed maintenance. All agent-initiated gateway restarts in this
runbook, including rollback, follow ADR 0005.

## Production validation checklist

Complete this checklist with the owner in an Interactive Verified-Owner Turn
before treating any broker change as production-ready. It uses one
non-sensitive disposable Vault Item and prints no bootstrap material or
Credential Response at any step.

1. Create a disposable Vault Item with a random username and password that
   grants access to nothing real. Note only its item name.
2. From the owner chat, ask Shelldon to fetch the disposable item for a
   downstream login. Confirm the gateway pauses for a Retrieval Approval
   (`Retrieve login credential`, allow-once / deny).
3. Approve once. Confirm Shelldon completes the downstream login without
   repeating the username or password in chat, channel progress, or any
   other reply surface.
4. Deny a second fetch and confirm it fails closed with no CLI invocation
   and no credential handling. Confirm an approval timeout or cancellation
   behaves the same way.
5. Confirm the persisted tool result contains only the redaction marker
   `[Vault Access Broker Credential Response redacted]`.
6. Confirm a non-authorized agent has no `vault_fetch` capability. For an
   Authorized Agent, cron, heartbeat, background, subagent, and unverified
   requester contexts still require one-time owner approval; no context may
   invoke the Bitwarden CLI after denial or without approval.
7. Confirm gateway health (`systemctl status`, local HTTP probe), a plugin
   reload receipt, and restart behavior without emitting bootstrap material.
   Confirm the only retrieval evidence is the normal OpenClaw
   approval/session record, which carries no credential values.
8. Delete the disposable Vault Item from the vault.

### Cache freshness regression

After verifying the new gateway PID and startup health, have the owner edit the
username of a non-sensitive disposable Vault Item in Vaultwarden and save it.
Then trigger `vault_fetch` through an Authorized Agent with one-time Retrieval
Approval and consume the response only for the downstream login. Confirm the
updated login is used without printing either field. Repeat after another
server-side edit to verify synchronization on every retrieval, not just the
first call after startup. Prefer the disposable item over modifying a real
login such as `linda-seeds`.

Compare only cache file metadata immediately before and after each approved
fetch:

```bash
stat -c 'cache modified=%y' \
  /home/shelldon/.local/lib/openclaw/vault-access-broker/state/data.json
```

The timestamp should advance for each successful sync, but metadata alone does
not prove the returned login is current; the downstream-use check is required.
Do not read or print `data.json`, bypass `vault_fetch` with the private CLI, or
repeat credentials in a test report. A Pi session without `vault_fetch` cannot
complete this live check: hand it to the owner-approved OpenClaw turn and report
it as pending rather than claiming production validation.

## Deliberate update and rollback

Changing the Bitwarden version is a maintenance change, never an automatic
upgrade. Before changing it, validate the candidate release's source and
reported version, complete the broker's controlled fake-CLI tests and production
validation checklist, then update all four version references together:

1. this runbook;
2. `runtime/openclaw-gateway.system.service`;
3. `runtime/vault-access-runtime-health` (including its binary digest pin);
4. both installed runtime files: `bin/bw` and
   `bin/vault-access-runtime-health`.

The Vaultwarden endpoint may change independently by editing
`/etc/openclaw/vault-access-broker.env` and restarting the system-managed
gateway. Keep it an absolute HTTPS URL; the health check rejects other values.

Keep the currently working runtime directory until the new gateway restart and
health check succeed. To roll back, restore the previous verified `bin/bw` and
matching `bin/vault-access-runtime-health`, restore the previous exact version
in the installed system unit, run `systemctl daemon-reload`, and restart the
gateway. Credentials do not need reenrollment for a binary-only rollback.

If the gateway fails its startup health check, do not weaken the check or move
credentials into environment variables. Inspect only service status and the
non-secret health error, restore the last known-good binary/unit pair, then
restart. Re-enroll a credential only when its encrypted file is missing or
corrupt.
