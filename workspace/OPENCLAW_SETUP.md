# OpenClaw "Shelldon" — Native Setup (v2026.9.5)

> This is the setup hand-off document. It lives in the tracked agent workspace at
> `/home/shelldon/.openclaw/workspace/OPENCLAW_SETUP.md`.

Fresh native install, September 2026. Replaces the previous Docker-based deployment.
No migration was performed — this is a clean setup; the old state is kept as backup.

## Overview

| Item | Value |
|---|---|
| Host | `ubuntu-8gb-nbg` (195.201.42.226, Hetzner nbg1) |
| OpenClaw version | 2026.9.5 (`ec9c1a1`) |
| Runtime | Native Node.js v24 (system `/usr/bin/node`), **not** Docker |
| Service user | `shelldon` (uid 1000) — gateway never runs as root |
| Public URL | `https://ai.sieh.org/` |
| Gateway bind / port | `lan` (0.0.0.0) / `18789` |
| Agent name | Shelldon |

## Layout (all owned by `shelldon`)

- `~/.openclaw/openclaw.json` — main config (mode `600`, **not** in git — holds the
  literal gateway token; `openclaw.json.example` is the tracked redacted copy)
- `~/.openclaw/workspace/` — agent workspace: `IDENTITY.md` + `USER.md` restored
  from backup (see below), `SOUL.md` kept from fresh install, `BOOTSTRAP.md`
  deleted, avatar at `avatars/shelldon.png`, this hand-off document
  (`OPENCLAW_SETUP.md`)
- `~/.openclaw/agents/shelldon/` — agent state, incl. `agent/openclaw-agent.sqlite` (provider credentials)
- `~/.npm-global/` — npm global prefix; CLI at `~/.npm-global/bin/openclaw`
- `~/.config/systemd/user/openclaw-gateway.service` — managed systemd user unit
- `~/.openclaw/.git/` — local setup-history repository (no remote configured)

## Service management (as `shelldon`)

```bash
export XDG_RUNTIME_DIR=/run/user/1000   # needed for systemctl --user over ssh/sudo
systemctl --user status openclaw-gateway.service
openclaw gateway status                  # includes connectivity probe
openclaw gateway restart
openclaw logs --follow
```

- Persistence across logouts: `loginctl enable-linger shelldon` (enabled).
- User manager: `user@1000.service` must be running for `systemctl --user` to work.

## Identity (restored from backup)

- `IDENTITY.md`: verbatim copy from `.openclaw_BAK` (Shelldon crab persona).
- `USER.md`: copy from `.openclaw_BAK`, except `## Professional Background`
  was replaced with a pointer to `https://henningsieh.de` — keeps the file at
  ~3.2 KB, under the 4,000-char session budget.
- `SOUL.md`: kept from the fresh install (untouched).
- `BOOTSTRAP.md`: deleted.
- Avatar: `workspace/avatars/shelldon.png` (restored from backup, renamed),
  wired as `agents.entries.shelldon.identity.avatar`.

## Config notes

- Gateway auth: `gateway.auth.mode: token`, token stored **literally** in `openclaw.json`
  (mode `600`, shelldon-only). SecretRef (`${OPENCLAW_GATEWAY_TOKEN}`) was tried
  and REJECTED for this purpose: the managed systemd service scrubs exactly this
  variable from the gateway environment, so the reference never resolves and the
  gateway falls back to a random per-start token (breaks all auth). SecretRefs
  remain fine for *provider* credentials — just not for the gateway ingress token.
  Live config stays out of git; `openclaw.json.example` (redacted) is tracked.
- `gateway.trustedProxies`: `["127.0.0.1", "::1", "172.25.0.6"]` — the new gateway
  requires the reverse-proxy IP listed narrowly (a `/24` range is rejected with
  `403 proxy_attribution_required`).
- `gateway.controlUi.allowedOrigins`: `["https://ai.sieh.org"]`.
- Default model: `opencode-go/muse-spark-1.3-contributor`, thinking `medium`
  (`agents.defaults.model.primary` + `agents.defaults.thinkingDefault`).
  ⚠️ The per-agent entry (`agents.entries.shelldon.model`) overrides the global
  default — both must point at the same model, otherwise new chats silently use
  the agent-level pin.
- Avatar: `workspace/avatars/shelldon.png` (restored from backup, renamed),
  wired as `agents.entries.shelldon.identity.avatar`.

## Repository tracking

The local repository is `/home/shelldon/.openclaw/`. It tracks setup/configuration
artifacts only — not runtime state or credentials.

Tracked on the initial setup commit:

- `.gitignore`
- `openclaw.json.example` (redacted configuration template)
- `workspace/` (agent instructions, identity, user model, soul, avatar, and this document)

Ignored deliberately:

- live `openclaw.json` and all automatic config backups (contain the gateway token)
- agent SQLite stores, sessions, browser data, runtime state, logs, caches, locks,
  temporary files, media, migration data, the regenerable `/npm/` plugin sandbox,
  and generated absolute symlinks under `/plugin-skills/`
- `config-journal-fingerprint.key`

The repository must remain local unless the live token is removed from the config
and all personal data is reviewed first. Use `git status` from `/home/shelldon/.openclaw`
to review changes before committing.

## Providers

- **opencode-go**: API key configured (key originally from `/root/openclaw/.env`,
  `OPENCODE_API_KEY`), activated, inference-verified. Credential lives in the
  agent sqlite store as profile `opencode-go:setup-<uuid>`; no env file needed
  at runtime. (The bare `opencode-go:default` profile was removed — redundant.)
- **Codex / OpenAI**: bundled `codex` plugin present; OAuth login not done yet (joint step).
- Previously used providers (nvidia, openrouter, google, telegram, discord, …) are
  **not** configured — to be pulled selectively from the backup (see below).

## Reverse proxy (Nginx Proxy Manager)

- NPM container `nginx_proxy_manager` terminates TLS and forwards
  `ai.sieh.org → 172.25.0.1:18789` (host gateway).
- Proxy host id **34**. Both the NPM database (`/opt/nginx-proxy-manager/data/database.sqlite`)
  and the generated file (`/opt/nginx-proxy-manager/data/nginx/proxy_host/34.conf`,
  backup: `34.conf.bak`) point at `172.25.0.1`.
- ⚠️ The generated `.conf` was edited directly + `nginx -s reload` because a plain
  container restart does not regenerate it from the DB. Editing host 34 in the NPM
  UI later regenerates from the DB — same value, harmless.
- ⚠️ NPM's container IP (`172.25.0.6`) is pinned in `trustedProxies`. If the NPM
  container is recreated with a different IP, update `gateway.trustedProxies`
  (`openclaw config set gateway.trustedProxies '["127.0.0.1", "::1", "<new-ip>"]'`)
  and restart the gateway.

## Backup / history

- Old Docker-era state: `/home/shelldon/.openclaw_BAK/` (config, credentials,
  workspace, memory, skills, channels — telegram/discord setups live here).
- Previous OpenClaw credential files: `/home/shelldon/.openclaw_BAK/credentials/`.
  Inspect selectively; do not replace the fresh state wholesale.
- Previous deployment secrets and service credentials: `/home/shelldon/.env`.
  This is a `600` `shelldon`-owned copy of the former `/root/openclaw/.env`.
  It contains provider/channel/service secrets and is a source for selective
  setup only; the native OpenClaw service does not load it automatically.
- Old deployment files (docker-compose.yml, Dockerfile.gateway, original `.env`):
  `/root/openclaw/`. The old image (`openclaw-local:2026.7.1-2`) was deleted.
- This doc's install log: fresh `openclaw onboard` (non-interactive, auth skipped
  initially), then `opencode-go` auth + daemon install + `config set` hardening.

## Install recipe (how this was built)

```bash
# as root: stop old world
cd /root/openclaw && docker compose down
docker rmi openclaw-local:2026.7.1-2
mv /home/shelldon/.openclaw /home/shelldon/.openclaw_BAK
loginctl enable-linger shelldon && systemctl start user@1000.service

# as shelldon (cwd MUST be /home/shelldon, never /root — npm subprocesses
# inherit cwd and shelldon cannot read /root, causing EACCES failures):
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh \
  | bash -s -- --version 2026.9.5 --no-onboard --verify
openclaw onboard --non-interactive --accept-risk --flow quickstart \
  --auth-choice skip --gateway-auth token --gateway-token <TOKEN> \
  --gateway-bind lan --gateway-port 18789 --agent-name Shelldon \
  --skip-channels --skip-hooks --skip-search --skip-skills --skip-ui \
  --no-install-daemon
# then: opencode-go onboard/auth, gateway install, literal token + narrow
# trustedProxies via `openclaw config set`, gateway restart, NPM repoint.
```

## Open items (joint session)

1. Codex (ChatGPT/Codex subscription) OAuth login.
2. Selective import from `.openclaw_BAK`: Telegram/Discord channels, skills, memory,
   workspace files (IDENTITY/USER/avatar already done), model fallbacks.
3. `shelldon` sudo/group privileges for future root-level tasks (to be defined).
