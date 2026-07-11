# Vaultwarden Integration

This directory contains the credential-fetching infrastructure for integrating with Vaultwarden (self-hosted password manager) within OpenClaw agents.

> Note: this README documents the repository/container integration and build/runtime helper behavior. It is not the OpenClaw skill manifest (`SKILL.md`) for an agent skill — that lives at `~/.openclaw/skills/vaultwarden/SKILL.md` on the host volume.

## Architecture

Two layers work together:

### 1. `openclaw-bw-resolver.mjs` — Core Protocol Handler (lower-level)

- **Role**: Implements OpenClaw's exec SecretRef protocol and the underlying vault-unlock/fetch logic. Also the engine behind the `vault_fetch` tool.
- **Input**: JSON over stdin with credential IDs to fetch
- **Output**: JSON with resolved credentials or errors
- **Security**: Requires `BW_*` environment variables (server URL, API key, master password)

**Protocol:**
```json
stdin:
{
  "protocolVersion": 1,
  "provider": "vaultwarden",
  "ids": ["openclaw/providers/openai/apiKey", "smtp/mailgun/token"]
}

stdout:
{
  "protocolVersion": 1,
  "values": {
    "openclaw/providers/openai/apiKey": "sk-...",
    "smtp/mailgun/token": "key-..."
  }
}
```

Installed at `/usr/local/bin/openclaw-bw-resolver` in the image, and registered as the `vaultwarden` exec provider under `secrets.providers` in `openclaw.json` for gateway-level SecretRef resolution (e.g. the qcard CardDAV password fetched at container startup by `openclaw-init.sh`).

### 2. `vault_fetch` tool plugin — agent credential access (primary)

- **Role**: Exposes a native OpenClaw agent-callable tool `vault_fetch({ name, mode? })` that retrieves a credential from the vault on demand, mid-task.
- **Location**: `plugins/vault-fetch/` in this repo, built at image build time (Dockerfile.gateway step 8) into `/home/node/.openclaw-plugin-vault-fetch/`, enabled via `plugins.load.paths` + `plugins.entries` in `openclaw.json`.
- **How it works**:
  1. The `execute()` handler runs **in-process** inside the gateway, so it has direct access to `process.env.BW_*`.
  2. It calls the `bw` CLI at `/home/node/.local/lib/bw-private` (private path, not on exec PATH) to unlock the vault, fetch the item, and lock the vault on every call.
  3. The credential value is returned to the agent as a typed tool result.

This **supersedes the old shell bridge** (`openclaw-vault-fetch`), which read `BW_*` from `/proc/1/environ` and has been removed.

## Security model

| Layer | Has Access | Note |
|-------|-----------|------|
| **Gateway process** | `BW_PASSWORD`, `BW_CLIENTID`, `BW_CLIENTSECRET` | Injected via `.env` + `env_file` in docker-compose |
| **`vault_fetch` tool plugin** | ✅ in-process `process.env.BW_*` | Runs as part of the gateway, not an exec subprocess |
| **Agent exec environment** | ❌ Blocked | `BW_*` stripped by host-env-security policy (Dockerfile `sed` patch) |
| **`openclaw-bw-resolver`** | ✅ When invoked by the gateway or `openclaw-init.sh` | Not callable from agent exec (env stripped) |

The agent only ever sees the *credential values* returned by the `vault_fetch` tool — never the master password or `BW_*` material itself.

## Usage (from an agent session)

Call the `vault_fetch` tool:

```
vault_fetch({ name: "my-service/api-key" })              # password (default)
vault_fetch({ name: "my-service/api-key", mode: "json" })  # full item object
vault_fetch({ name: "my-service/api-key#notes" })          # Secure Note body
vault_fetch({ name: "my-service/api-key#customFieldName" })# custom field
```

The agent learns this from the `vaultwarden` skill (`~/.openclaw/skills/vaultwarden/SKILL.md`).

## Item naming convention

Create Login items in Vaultwarden whose **Name** field exactly matches the credential id:

- `x.com (Django ElRey)` — stored in Vaultwarden with that exact name
- `openclaw/providers/openai/apiKey` — stored with that path-like name
- `openclaw/qcard/henning@sieh.org` — qcard CardDAV password (fetched at startup)

### Field selectors

By default, `vault_fetch` returns the **password** field. Use suffix selectors for other fields:

- `#notes` — Secure Note body
- `#<customFieldName>` — named custom field

## Environment variables

**Required** (injected by docker-compose → gateway process env):

| Variable | Example | Purpose |
|----------|---------|---------|
| `BW_SERVER_URL` | `https://vault.example.com` | Vaultwarden base URL |
| `BW_CLIENTID` | `client-id-xxx` | API client ID (from Vaultwarden account settings) |
| `BW_CLIENTSECRET` | `client-secret-xxx` | API client secret (paired with client ID) |
| `BW_PASSWORD` | `master-password` | Master password to unlock vault |

**Optional:**

| Variable | Default | Purpose |
|----------|---------|---------|
| `BW_BIN` | `/home/node/.local/lib/bw-private` | Path to `bw` CLI binary |

Leave all `BW_*` empty to disable Vaultwarden integration.

## Build / installation

The resolver is copied into the image at build time:

```dockerfile
COPY scripts/vaultwarden/openclaw-bw-resolver.mjs /usr/local/bin/openclaw-bw-resolver
RUN chmod +x /usr/local/bin/openclaw-bw-resolver
```

The tool plugin is built and validated at build time (see `Dockerfile.gateway` step 8 and `plugins/vault-fetch/README.md`).

## Troubleshooting

**Error: "BW resolver: missing required env vars"**
- Ensure `.env` has all four `BW_*` variables set
- Verify they're in `docker-compose.yml`'s `env_file` or `environment`

**Error: "bw login failed"**
- Check `BW_SERVER_URL` is reachable
- Verify `BW_CLIENTID` and `BW_CLIENTSECRET` match Vaultwarden account settings

**`vault_fetch` tool not visible to the agent**
- Check `openclaw plugins list --enabled` shows `vault-fetch` as `enabled`
- Check `openclaw plugins inspect vault-fetch --runtime` shows `Status: loaded` and `Tools: vault_fetch`
- Verify `plugins.load.paths` includes `/home/node/.openclaw-plugin-vault-fetch` and `plugins.entries["vault-fetch"].enabled` is true
- Restart/reload the gateway after config changes

**Credential not found**
- Verify the item name in Vaultwarden exactly matches the id you are requesting
- Check for typos and case sensitivity