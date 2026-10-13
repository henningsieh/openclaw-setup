# Coolify Access Paths

Three independent paths, each verified live against the Coolify server. Pick by task.

## 1. SSH to the Coolify host (host, containers, compose, files)

- Key: `~/.openclaw/workspace/coolify-server-access/ssh_key` (ed25519). Keep keys in the workspace,
  never in a home directory — container rebuilds wipe there.
- Internal (preferred, over the `network-1` private net): `ssh -i ~/.openclaw/workspace/coolify-server-access/ssh_key root@10.0.0.3`
- Public fallback: same command with `root@188.245.144.137`
- Verify: returns hostname `coolify-ubuntu-4gb-nbg1-4`; `docker ps` lists `coolify`, `coolify-db`,
  `coolify-redis`, `coolify-realtime`, `coolify-sentinel`.

## 2. REST API via the helper script

⚠️ **Never use agent-authored inline `curl` for Coolify REST.** It returns `401` even with a valid
token — the exec/secret-masking layer rewrites the token literal in the command text to a
placeholder (`***`) before the request goes out. `401` means masking, not a bad token: do not
rotate credentials or chase Coolify auth. Use this script (token resolves inside the script), or
the `coolify__*` MCP tools. If raw `curl` is unavoidable, never inline the token: use `curl -H
@file`, `"Authorization: ***"` indirection, or have the gateway resolve
`${COOLIFY_API_TOKEN}`.

- Script: `~/.openclaw/workspace/coolify-server-access/coolify_api.sh`; reads `COOLIFY_API_TOKEN`
  from the environment and sends `Authorization: Bearer <token>`.
- Base: `https://<coolify-host>/api/v1`
- Usage:
  ```bash
  ./coolify_api.sh GET "servers"
  ./coolify_api.sh POST "endpoint" '{"key":"value"}'
  ```
- Useful endpoints: `servers`, `projects`, `applications/{uuid}`, `applications/{uuid}/envs`
  for reads. There is no working per-key PATCH: `PATCH .../envs/{uuid}` and singular
  `.../env` both answer 404 — update an env by re-listing for its current UUID (UUIDs are
  re-versioned on every write, a minutes-old one is stale), then DELETE plus POST with
  the previous flags; the full verified procedure is `coolify-preview-deployments` step 4.
  `deployments/applications/{uuid}` for deployment history (not re-verified here).
- Application creation has no API route on this server (verified 2026-10-11):
  `POST /applications` answers 404 `{"message":"Not found."}` with and without a body —
  the route is absent, not the payload wrong — and even `GET /system/version` 404s while
  `GET applications|projects` succeed. Create new apps in the Coolify UI (project →
  environment → New → Application, then repo/branch/build/domain), and resume automation
  at deploy/verify (`coolify__deploy`, `deployments/applications/{uuid}`). Do not probe
  alternate create shapes; the 404 is conclusive. MCP likewise offers lifecycle tools for
  existing apps only, no creation.
- Verify: `GET servers` returns `HTTP:200` and a JSON array.

## 3. MCP server (structured, tool-based)

- Configured in `~/.openclaw/openclaw.json` at `.mcp.servers.coolify`: `url
  https://<coolify-host>/mcp`, `transport streamable-http`, header
  `Authorization: Bearer ${COOLIFY_API_TOKEN}`.
- The header resolves from the gateway process environment, so the token must be loaded before the
  MCP client connects (see SKILL.md step 2). Editing `mcp.servers` hot-reloads the config; the
  server itself connects at gateway startup.
- Handshake check:
  ```bash
  curl -s -X POST https://<coolify-host>/mcp \
    -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"agent","version":"1"}}}'
  ```
- Exposes `coolify_*` tools: `coolify_help` (intent catalog), plus list/get for servers, projects,
  applications, databases, and services.
- Verify: the initialize call returns `serverInfo.name = "Coolify"`.

## 4. Environment values and database connection strings

- `list_env_keys` (MCP) returns key names only, never values — by design, not a
  permission problem. To assemble a local `.env`, use the REST path, which returns
  values: `./coolify_api.sh GET "applications/{uuid}/envs"`. Parse and redact in the
  same pipeline — print key names and counts only, never secret values.
- A database object's `internal_db_url` uses a UUID hostname on `:5432` that resolves
  only inside Coolify's container network. From this host, use the external shape
  instead: the `external_db_url` host (`188.245.144.137:<public_port>`) or, preferred
  on the private net, `10.0.0.3:<public_port>`. The service-level database name may be
  the maintenance database (`postgres`); the application's actual database name comes
  from the app's own docs or `.env.example` comment, not from the service object.
- Verify: TCP-connect (or `getent hosts`) against the chosen host:port before writing
  any `.env`; compare the app's `DATABASE_URL` host (parsed, redacted) against the
  intended service to catch stale pointers (e.g. still aimed at a deleted database).
- No public port (`is_public: false`, no `public_port` on the database object): there is
  no external shape — tunnel to the container **IP** (`docker inspect {cid}` →
  `NetworkSettings.Networks.*.IPAddress`), never to the Docker-DNS UUID hostname, which
  even the Coolify host cannot resolve (`getent hosts` empty). The full tunneled
  migrate/seed flow lives in `coolify-preview-deployments` step 3.

## Notes

- Token format is `ID|secret`.
- `/deployments` lists only in-progress deployments; use `/deployments/applications/{uuid}` for
  history.
