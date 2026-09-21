# Vault Access Broker

Credential-free Local Plugin Source for Shelldon's Vault Access Broker. It is a
native OpenClaw managed-plugin package pinned to OpenClaw `2026.9.5`.

## Capability and policy

The package owns one optional tool: `vault_fetch`. Optional metadata means the
tool is not included in any agent's catalog merely because the plugin is
installed. A later activation change must explicitly allowlist it in
Shelldon's agent-specific tool policy; no other agent receives access by
default.

`vault_fetch` is exposed only to Shelldon. Every Shelldon invocation, regardless
of requester, channel, or session type, requests an allow-once Retrieval
Approval; denial, timeout, cancellation, or unavailable approval routes fail
closed. Configure an explicit `approvals.plugin` route to the owner's approval-capable
channel so requests that originate elsewhere can be reviewed.

The controlled CLI boundary configures the Vaultwarden endpoint,
authenticates and unlocks only when needed, searches for a Vault Item by exact
name before accepting one fallback candidate, and attempts to lock the vault in
all outcomes. It returns only a username-and-password Credential Response. Tool
result persistence replaces that response with a redaction marker, so it must
be used for the downstream login and never repeated in chat.

## Test seam

Tests exercise `vault_fetch` through its loaded registration surface and use a
controlled fake Bitwarden CLI boundary. They never contact Vaultwarden, read
real credential files, or invoke the installed Bitwarden CLI.

## Local verification

```bash
pnpm install
pnpm test
pnpm run plugin:validate
pnpm exec openclaw plugins inspect vault-access-broker --runtime --json
pnpm exec openclaw plugins pack --root . --out ./vault-access-broker-0.1.0.tgz
```

`plugins inspect` requires an installed package; package and enable this source
only through OpenClaw's managed plugin lifecycle. Do not add a runtime plugin
path or credential material to this repository.
