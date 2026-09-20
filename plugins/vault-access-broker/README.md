# Vault Access Broker

Credential-free Local Plugin Source for Shelldon's Vault Access Broker. It is a
native OpenClaw managed-plugin package pinned to OpenClaw `2026.9.5`.

## Capability and policy

The package owns one optional tool: `vault_fetch`. Optional metadata means the
tool is not included in any agent's catalog merely because the plugin is
installed. A later activation change must explicitly allowlist it in
Shelldon's agent-specific tool policy; no other agent receives access by
default.

This foundation deliberately does not configure a Bitwarden executable, service
credentials, a Vaultwarden URL, or a tool-policy grant. Until the Pinned Vault
Access Runtime and approved retrieval behavior are implemented, invoking the
tool fails closed without opening a vault connection.

## Test seam

Tests exercise `vault_fetch` through the plugin's loaded registration surface.
They use no Vaultwarden service, credential data, or real Bitwarden CLI. The
follow-on retrieval implementation must retain this public-tool seam and
substitute a controlled fake Bitwarden CLI at its process boundary.

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
