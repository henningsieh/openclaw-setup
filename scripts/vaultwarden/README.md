# Vaultwarden Integration

This directory contains the credential-fetching infrastructure for integrating with Vaultwarden (self-hosted password manager) within OpenClaw agents.

> Note: this README documents the repository/container integration and build/runtime helper behavior. It is not the OpenClaw skill manifest (`SKILL.md`) for an agent skill.

## Architecture

Two complementary pieces work together to bridge a security boundary:

### 1. `openclaw-bw-resolver.mjs` — Core Protocol Handler

- **Role**: Translates between OpenClaw's credential protocol and Vaultwarden's `bw` CLI
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

### 2. `vault-fetch` — Exec Bridge

- **Role**: Bridges the security boundary between agent exec environments and credential storage
- **How it works**:
  1. Reads `BW_*` variables from gateway's `/proc/1/environ` (process 1 = gateway)
  2. Calls the resolver with those credentials loaded
  3. Returns plaintext credential to agent session

**Implementation detail:** The actual executable stored in the image is `openclaw-vault-fetch`, but agents should invoke it through the alias `vault-fetch`.

**Naming note:** `openclaw-vault-fetch` deliberately has no `.sh` extension so it behaves like a normal CLI helper command when installed in `/usr/local/bin`.

## Why Two Files?

This is **intentional security design**:

**Without the bridge:**
```bash
# Agent tries to call resolver directly
echo '{"protocolVersion":1,...}' | node /usr/local/bin/openclaw-bw-resolver
# → Error: BW_PASSWORD not available
# (stripped by host-env-security policy in Dockerfile step 7)
```

**With the bridge:**
```bash
# Agent calls the fetch script
vault-fetch "x.com (Django ElRey)"
# → R3qj#e&QSuMh

# How it works internally:
# 1. Script reads BW_* from /proc/1/environ (gateway process has them)
# 2. Script calls resolver with credentials loaded
# 3. Returns credential to agent
```

## Security Model

| Layer | Has Access | Note |
|-------|-----------|------|
| **Gateway process (PID 1)** | `BW_PASSWORD`, `BW_CLIENTID`, `BW_CLIENTSECRET` | Injected via `.env` + `passEnv` in docker-compose |
| **Agent exec environment** | ❌ Blocked | Credentials stripped by host-env-security policy |
| **vault-fetch** | ✅ Via `/proc/1/environ` | Can read gateway's env, forwards to resolver |
| **openclaw-bw-resolver** | ✅ If called with creds | Handles vault unlock and item retrieval |

## Usage

From within an agent session:

```bash
# Fetch a specific credential
password=$(vault-fetch "my-service/api-key")

# Use in downstream tools
curl -H "Authorization: Bearer $password" https://api.example.com
```

## Item Naming Convention

Create Login items in Vaultwarden whose **Name** field exactly matches the credential ID:

- `x.com (Django ElRey)` — stored in Vaultwarden with that exact name
- `openclaw/providers/openai/apiKey` — stored with that path-like name
- `smtp/mailgun/token` — stored with that path-like name

### Field Selectors

By default, the resolver returns the **password** field. Use suffix selectors for other fields:

```bash
# Password field (default)
vault-fetch "my-service/api-key"

# Secure Note body
vault-fetch "my-service/api-key#notes"

# Custom field
vault-fetch "my-service/api-key#customFieldName"
```

## Installation & Deployment

Both files are copied into the Docker image at build time:

```dockerfile
COPY scripts/vaultwarden/openclaw-bw-resolver.mjs /usr/local/bin/openclaw-bw-resolver
COPY scripts/vaultwarden/openclaw-vault-fetch /usr/local/bin/openclaw-vault-fetch
RUN chmod +x /usr/local/bin/openclaw-bw-resolver /usr/local/bin/openclaw-vault-fetch
RUN ln -sf /usr/local/bin/openclaw-vault-fetch /usr/local/bin/vault-fetch
```

## Environment Variables

**Required** (injected by docker-compose → `/proc/1/environ`):

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

## Troubleshooting

**Error: "BW resolver: missing required env vars"**
- Ensure `.env` has all four `BW_*` variables set
- Verify they're in `docker-compose.yml`'s `env_file` or `environment`

**Error: "bw login failed"**
- Check `BW_SERVER_URL` is reachable
- Verify `BW_CLIENTID` and `BW_CLIENTSECRET` match Vaultwarden account settings

**Credential not found**
- Verify the item name in Vaultwarden exactly matches the ID you're requesting
- Check for typos and case sensitivity
