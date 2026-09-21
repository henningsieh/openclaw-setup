# Vault Access Broker

Credential-free Local Plugin Source for Shelldon's Vault Access Broker. It is a
native OpenClaw managed-plugin package pinned to OpenClaw `2026.9.5`.

## Capability and policy

The package owns one optional tool: `vault_fetch`. Optional metadata means the
tool is not included in any agent's catalog merely because the plugin is
installed; it requires an explicit allowlist entry in that agent's tool policy.

`vault_fetch` is exposed only to Shelldon, requires a one-time owner Retrieval
Approval on every invocation, and fails closed on denial, timeout, cancellation,
or an unavailable approval route. A Credential Response is use-only and is
replaced by a redaction marker on persistence, so it must never be repeated in
chat.

Domain vocabulary lives in `CONTEXT.md` (Vault Credential Access). Activation,
approval routing, and the production validation checklist live in
`docs/runbooks/vault-access-runtime.md`.

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
