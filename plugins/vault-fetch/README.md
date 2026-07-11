# vault-fetch (OpenClaw tool plugin)

An OpenClaw **tool plugin** that exposes a single agent-callable tool,
`vault_fetch`, for retrieving credentials from a self-hosted **Vaultwarden**
vault via the Bitwarden CLI (`bw`).

This supersedes the older shell-based `vault-fetch` bridge
(`scripts/vaultwarden/openclaw-vault-fetch`) which read `BW_*` from
`/proc/1/environ`.

## Why a tool plugin

- **Native interface:** the agent calls a typed tool name (`vault_fetch`)
  that OpenClaw projects natively, instead of shelling out to a binary on
  `PATH`.
- **No env-hack:** the `execute()` handler runs in-process inside the gateway,
  so it has direct access to `process.env.BW_*`. There is no `/proc/1/environ`
  read and no reliance on the exec-tool env-stripping workaround.
- **Security boundary preserved:** `BW_*` are still stripped from the agent's
  `exec` tool subprocess environment by the gateway's host-env-security
  policy. The agent only ever sees the *credential values* this tool returns —
  never the master password.

## The credential circle

1. Agent needs a credential mid-task (e.g. "log into Amazon, read my cart").
2. Agent reads the `vaultwarden` skill → learns to call the `vault_fetch` tool.
3. Agent calls `vault_fetch({ name: "Amazon" })` → gateway runs the plugin
   in-process → `bw` unlocks the vault, fetches the item, locks the vault, and
   returns the value to the agent as a typed tool result.
4. Agent uses the result with the existing `browser-use` skill (unchanged).

## Parameters

| Parameter | Type | Description |
|---|---|---|
| `name` | `string` | Vault item name (`Name` field in Vaultwarden). Append `#notes` for a Secure Note body, or `#<customFieldName>` for a custom field. |
| `mode` | `"password" \| "json"` | Return shape. `password` (default) returns the item's password. `json` returns the full item object (username, password, notes, custom fields). |

## Returns

- `password` mode: the password string, or
  `{ error: true, message: "..." }` on failure.
- `json` mode: `{ name, item }` with the full item object, or
  `{ error: true, message: "..." }` on failure.

## Configuration

No plugin config is required. The plugin reads `BW_*` from the gateway
process environment, which are injected via `.env` + `env_file` in
`docker-compose.yml`:

| Variable | Purpose |
|---|---|
| `BW_SERVER_URL` | Vaultwarden base URL |
| `BW_CLIENTID` | API client id |
| `BW_CLIENTSECRET` | API client secret |
| `BW_PASSWORD` | Master password (used only to unlock) |
| `BW_BIN` | Optional path to `bw` binary (default `/home/node/.local/lib/bw-private`) |

Leave `BW_*` empty to disable the integration.

## Build

The plugin is built at Docker image build time (see `Dockerfile.gateway`).
To build + validate manually inside the image:

```sh
NODE_ENV=development npm install --ignore-scripts --no-audit --no-fund
npx tsc -p tsconfig.json
node /app/dist/index.js plugins build --entry ./dist/index.js
node /app/dist/index.js plugins validate --entry ./dist/index.js
```

Runtime dependencies (`typebox`) are resolved from the plugin's own
`node_modules` shipped in the image; `openclaw/plugin-sdk/tool-plugin` resolves
to the bundled `/app` package at runtime.