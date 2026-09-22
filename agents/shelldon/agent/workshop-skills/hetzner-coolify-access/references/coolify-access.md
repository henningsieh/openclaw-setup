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
- Base: `https://coolify.sieh.org/api/v1`
- Usage:
  ```bash
  ./coolify_api.sh GET "servers"
  ./coolify_api.sh POST "endpoint" '{"key":"value"}'
  ```
- Useful endpoints: `servers`, `projects`, `applications/{uuid}`, `applications/{uuid}/envs`
  (PATCH matches by `key`), `deployments/applications/{uuid}` for deployment history.
- Verify: `GET servers` returns `HTTP:200` and a JSON array.

## 3. MCP server (structured, tool-based)

- Configured in `~/.openclaw/openclaw.json` at `.mcp.servers.coolify`: `url
  https://coolify.sieh.org/mcp`, `transport streamable-http`, header
  `Authorization: Bearer ${COOLIFY_API_TOKEN}`.
- The header resolves from the gateway process environment, so the token must be loaded before the
  MCP client connects (see SKILL.md step 2). Editing `mcp.servers` hot-reloads the config; the
  server itself connects at gateway startup.
- Handshake check:
  ```bash
  curl -s -X POST https://coolify.sieh.org/mcp \
    -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"agent","version":"1"}}}'
  ```
- Exposes `coolify_*` tools: `coolify_help` (intent catalog), plus list/get for servers, projects,
  applications, databases, and services.
- Verify: the initialize call returns `serverInfo.name = "Coolify"`.

## Notes

- Token format is `ID|secret`.
- `/deployments` lists only in-progress deployments; use `/deployments/applications/{uuid}` for
  history.
