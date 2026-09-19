# OpenClaw "Shelldon" — Native Setup (v2026.9.5)

> This is the setup hand-off document. It lives in the tracked agent workspace at
> `/home/shelldon/.openclaw/workspace/OPENCLAW_SETUP.md`.
>
> **Documentation rule for all OpenClaw documentation page URLs:** append
> `.md` to the URL to fetch clean Markdown. For example,
> `https://docs.openclaw.ai/cli/status.md`. This applies to every docs page link;
> index files such as `llms.txt` are already Markdown indexes.

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

## Official documentation

Index and reference pages, ordered to match how they're used below (onboarding →
providers → gateway/secrets → channels → automation → concepts → security).
Every link carries `.md` per the rule above; only the `llms.txt` index is exempt.

- **Documentation index (agents):** https://docs.openclaw.ai/llms.txt
- **CLI reference:** https://docs.openclaw.ai/cli.md
- **Onboarding (CLI):** https://docs.openclaw.ai/start/wizard.md
- **CLI setup reference:** https://docs.openclaw.ai/start/wizard-cli-reference.md
- **`openclaw status`:** https://docs.openclaw.ai/cli/status.md
- **Backup:** https://docs.openclaw.ai/cli/backup.md

**Models and provider auth**
  - https://docs.openclaw.ai/cli/models.md
  - https://docs.openclaw.ai/concepts/models.md
  - https://docs.openclaw.ai/concepts/model-providers.md
  - https://docs.openclaw.ai/concepts/model-providers/official-provider-plugins.md
  - https://docs.openclaw.ai/gateway/config-agents/models.md
  - https://docs.openclaw.ai/providers/openai/setup.md
  - https://docs.openclaw.ai/plugins/codex-harness.md

**Gateway configuration & secrets**
  - https://docs.openclaw.ai/gateway/configuration-reference.md
  - https://docs.openclaw.ai/plugins/manage-plugins.md
  - https://docs.openclaw.ai/gateway/config-secrets-env.md
  - https://docs.openclaw.ai/gateway/secrets.md
  - https://docs.openclaw.ai/gateway/secrets/secretref-contract.md
  - https://docs.openclaw.ai/cli/secrets.md

**Channels**
  - Overview: https://docs.openclaw.ai/channels.md
  - Discord — setup: https://docs.openclaw.ai/channels/discord/setup.md
  - Discord — access control: https://docs.openclaw.ai/channels/discord/access-control.md
  - Discord — troubleshooting: https://docs.openclaw.ai/channels/discord/troubleshooting.md
  - Telegram — setup: https://docs.openclaw.ai/channels/telegram/setup.md
  - Telegram — access control: https://docs.openclaw.ai/channels/telegram/access-control.md
  - Telegram — troubleshooting: https://docs.openclaw.ai/channels/telegram/troubleshooting.md
  - Pairing / access control: https://docs.openclaw.ai/channels/pairing.md

**Cron / automations**
  - https://docs.openclaw.ai/cli/cron.md
  - https://docs.openclaw.ai/automation/cron-jobs.md
  - https://docs.openclaw.ai/automation/cron-jobs/managing-jobs.md

**Concepts**
  - User/profile model: https://docs.openclaw.ai/concepts/user-model.md
  - Memory: https://docs.openclaw.ai/concepts/memory.md
  - Builtin memory engine: https://docs.openclaw.ai/concepts/memory-builtin.md

**Web tools**
  - https://docs.openclaw.ai/tools/web.md
  - https://docs.openclaw.ai/tools/duckduckgo-search.md

**Control UI**
  - https://docs.openclaw.ai/web/control-ui.md
  - https://docs.openclaw.ai/web/control-ui/sessions-and-sidebar.md

**Security**
  - https://docs.openclaw.ai/gateway/security.md
  - https://docs.openclaw.ai/gateway/security/secrets-and-storage.md

When a local command and a remembered procedure disagree, check the docs for
OpenClaw `2026.9.5` behavior and verify with `openclaw <command> --help` as the
installed CLI is authoritative for this host.

## Layout (all owned by `shelldon`)

- `~/.openclaw/openclaw.json` — main config (mode `600`, **not** in git — holds the
  literal gateway token; `openclaw.json.example` is the tracked redacted copy)
- `~/.openclaw/workspace/` — agent workspace: `IDENTITY.md` + `USER.md` restored
  from backup (see below), `SOUL.md` kept from fresh install, `BOOTSTRAP.md`
  deleted, avatar at `avatars/shelldon.png`, this hand-off document
  (`OPENCLAW_SETUP.md`)
- `~/.openclaw/agents/shelldon/` — agent state, incl. `agent/openclaw-agent.sqlite` (provider credentials)
  and the ignored `agent/codex-home/` (Codex app-server runtime state).
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
- Configured default model: `opencode-go/muse-spark-1.3-contributor`, thinking
  `high`, with no configured fallbacks (`agents.defaults.model.primary`,
  `agents.defaults.thinkingDefault`, and `agents.defaults.model.fallbacks`).
  `agents.defaults.models` also declares `openai/gpt-5.6-luna` as a selectable
  model. The per-agent entry (`agents.entries.shelldon.model`) points at the same
  OpenCode model, with its auth-profile suffix.
- The Control UI's `+` New Session flow independently remembers the latest model
  choice per Gateway user/agent and may preselect Luna even while the configured
  primary remains OpenCode. There is currently no config switch to disable that
  preference; selecting Muse Spark once in the New Session picker updates it.

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
  temporary files, media, migration data, the Codex app-server home under
  `/agents/*/codex-home/`, the regenerable `/npm/` plugin sandbox, and generated
  absolute symlinks under `/plugin-skills/`
- `config-journal-fingerprint.key`

The repository must remain local unless the live token is removed from the config
and all personal data is reviewed first. Use `git status` from `/home/shelldon/.openclaw`
to review changes before committing.

## Re-setup runbook: Discord and Telegram

The native installation currently has neither channel enabled. Everything needed
for a selective re-setup is preserved locally:

- **Previous secrets:** `/home/shelldon/.openclaw_BAK/.env` (mode `600`, owned by
  `shelldon`). The relevant variable names are `DISCORD_BOT_TOKEN` and
  `TELEGRAM_BOT_TOKEN`. Never copy their values into this document, Git, or chat.
- **Previous channel configuration:**
  `/home/shelldon/.openclaw_BAK/openclaw.json` under `channels.discord` and
  `channels.telegram` (also contains the old token values; do not copy the whole
  file into the fresh setup).
- **Previous channel-related memory:**
  `/home/shelldon/.openclaw_BAK/workspace/memory/` (search the Telegram/Discord
  daily notes if historical context is needed).

Use the official setup pages first:

- **Discord setup:** https://docs.openclaw.ai/channels/discord/setup.md
- **Discord access control:** https://docs.openclaw.ai/channels/discord/access-control.md
- **Telegram setup:** https://docs.openclaw.ai/channels/telegram/setup.md
- **Telegram access control:** https://docs.openclaw.ai/channels/telegram/access-control.md
- **Channel CLI:** https://docs.openclaw.ai/cli/channels.md

All commands below run as `shelldon`, from `/home/shelldon`, and use the existing
user service. Do not run OpenClaw as root.

### Discord recovery

1. In the Discord Developer Portal, verify the old bot or create a replacement.
   Enable **Message Content Intent** and **Server Members Intent**; invite it with
   `bot` and `applications.commands` plus View Channels, Send Messages, Read
   Message History, Embed Links, and Attach Files. The official setup page above
   has the exact portal steps.
2. Enable Developer Mode and retain these old IDs:
   - Server/guild: `1489535366854610994`
   - Owner/user: `400054493640916993`
   - Previously enabled channels: `1489535368859488421`,
     `1489587973715656786`, `1514565511223181363`, `1524758094079459418`
3. Start guided setup and enter the token locally when prompted. Retrieve it from
   `/home/shelldon/.openclaw_BAK/.env`; do not print it:

   ```bash
   cd /home/shelldon
   openclaw channels add --channel discord
   ```
4. The previous policy was `groupPolicy: "open"`, `allowBots: true`,
   `requireMention: false` for the guild, restricted to the four channels above
   and owner ID above. If that exact behavior is wanted, apply this **token-free**
   policy patch after adding the account:

   ```json5
   {
     channels: {
       discord: {
         enabled: true,
         allowBots: true,
         groupPolicy: "open",
         threadBindings: { spawnSessions: true },
         guilds: {
           "1489535366854610994": {
             requireMention: false,
             users: ["400054493640916993"],
             channels: {
               "1489535368859488421": { enabled: true, users: ["400054493640916993"] },
               "1489587973715656786": { enabled: true, users: ["400054493640916993"] },
               "1514565511223181363": { enabled: true, users: ["400054493640916993"] },
               "1524758094079459418": { enabled: true, users: ["400054493640916993"] }
             }
           }
         }
       }
     }
   }
   ```

   Save that as a temporary file outside the repository, run
   `openclaw config patch --file <file> --dry-run`, then apply it without
   `--dry-run` and remove the temporary file. Review the `groupPolicy: "open"`
   choice before applying; `allowlist` is safer for a shared server.

### Telegram recovery

1. Verify the old bot with `@BotFather`, or create a replacement with `/newbot`.
   Keep the token local in `/home/shelldon/.openclaw_BAK/.env` under
   `TELEGRAM_BOT_TOKEN`.
2. The old owner/user ID is `8788775758`. The old policy was:
   `dmPolicy: "allowlist"`, `allowFrom: ["8788775758"]`,
   `groupPolicy: "allowlist"`, `groupAllowFrom: ["8788775758"]`, and
   `groups: { "*": { requireMention: true } }`. No specific group IDs were
   recorded; replace `"*"` with explicit negative `-100...` group IDs if tighter
   access is required.
3. Start guided setup and enter the token locally when prompted:

   ```bash
   cd /home/shelldon
   openclaw channels add --channel telegram
   ```

4. Reapply the old token-free access policy if desired:

   ```json5
   {
     channels: {
       telegram: {
         enabled: true,
         dmPolicy: "allowlist",
         allowFrom: ["8788775758"],
         groupPolicy: "allowlist",
         groupAllowFrom: ["8788775758"],
         groups: { "*": { requireMention: true } },
         streaming: { mode: "partial" }
       }
     }
   }
   ```

### Verify and pair

After either channel is configured:

```bash
openclaw config validate
openclaw gateway restart
openclaw channels status --probe
openclaw status --deep
```

For first-user access, DM each bot and approve the pairing code locally:

```bash
openclaw pairing list discord
openclaw pairing approve discord <CODE>
openclaw pairing list telegram
openclaw pairing approve telegram <CODE>
```

The old Discord routing also had channel `1524758094079459418` bound to a
legacy `clawfred` agent, with other Discord traffic routed to `main`. Those
agents do not exist in the fresh native setup; do not restore that binding unless
they are deliberately recreated. The current setup should use the `shelldon`
agent by default.

## Providers

- **opencode-go**: API key configured (key originally from `/root/openclaw/.env`,
  `OPENCODE_API_KEY`), activated, inference-verified. Credential lives in the
  agent sqlite store as profile `opencode-go:setup-<uuid>`; no env file needed
  at runtime. (The bare `opencode-go:default` profile was removed — redundant.)
- **Codex / OpenAI**: the bundled `codex` plugin is installed and enabled;
  ChatGPT/Codex OAuth is configured and verified for the `shelldon` agent as
  profile `openai:henning@sieh.org` (stored in the agent SQLite auth store).
  `openai/gpt-5.6-luna` has been tested successfully with
  `Runtime: OpenAI Codex`. The configured default remains
  `opencode-go/muse-spark-1.3-contributor`.
- **Plugins**: relevant enabled plugins are the OpenAI provider, OpenCode Go
  provider, OpenCode provider, Codex harness, and DuckDuckGo search plugin.
  After installing the Codex plugin, `openclaw plugins registry --refresh` and a
  Gateway restart were required to make the harness available to new sessions.
- **Web search**: `web_search` and `web_fetch` are enabled; the DuckDuckGo
  experimental plugin is installed and enabled as the key-free search provider.
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
- Previous deployment secrets and service credentials: `/home/shelldon/.openclaw_BAK/.env`.
  This is a `600` `shelldon`-owned copy of the former `/root/openclaw/.env`, kept
  inside the old deployment backup. It contains provider/channel/service secrets
  and is a source for selective setup only; the native OpenClaw service does not
  load it automatically.
- Original deployment files (docker-compose.yml, Dockerfile.gateway, original
  `.env`): `/root/openclaw/`. The old image (`openclaw-local:2026.7.1-2`) was deleted.
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

1. Selective import from `.openclaw_BAK`: Telegram/Discord channels, skills, memory,
   workspace files (IDENTITY/USER/avatar already done), model fallbacks.
2. `shelldon` sudo/group privileges for future root-level tasks (to be defined).
