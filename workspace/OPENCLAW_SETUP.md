# OpenClaw "Shelldon" — Native Setup (v2026.9.5)

> This is the setup hand-off document. It lives in the tracked agent workspace at
> `/home/shelldon/.openclaw/workspace/OPENCLAW_SETUP.md`.
>
> **Documentation rule for all OpenClaw documentation page URLs:** append
> `.md` to the URL to fetch clean Markdown. For example,
> `https://docs.openclaw.ai/cli/status.md`. This applies to every docs page link;
> index files such as `llms.txt` are already Markdown indexes.

Native install, September 2026, replacing the previous Docker-based deployment.
It began clean, then selectively restored the native workspace identity, channels,
automations, and wiki. The complete Docker-era state remains preserved as backup.

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
- `~/.openclaw/workspace/` — agent workspace: restored `IDENTITY.md` + `USER.md`,
  fresh-install `SOUL.md`, compact wiki-routing `MEMORY.md`, avatar at
  `avatars/shelldon.png`, and this hand-off document (`OPENCLAW_SETUP.md`);
  `BOOTSTRAP.md` is deleted
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
- Configured default model: `openai/gpt-5.6-luna`, thinking `high`, with no
  configured fallbacks (`agents.defaults.model.primary`,
  `agents.defaults.thinkingDefault`, and `agents.defaults.model.fallbacks`).
  The per-agent entry (`agents.entries.shelldon.model`) also uses
  `openai/gpt-5.6-luna`. OpenClaw's current canonical provider prefix is
  `openai/`; the older `openai-codex/` prefix is legacy. The OpenAI OAuth profile
  is stored in the native agent auth store.
- The Control UI's `+` New Session flow independently remembers the latest model
  choice per Gateway user/agent. It may preselect a previously selected model;
  select `openai/gpt-5.6-luna` explicitly if needed.

## Memory and wiki migration

- The bundled `memory-wiki` plugin is enabled in bridge mode with its native vault
  at `~/.openclaw/wiki/main`. The legacy wiki has been restored there, excluding
  its old compiled cache and `log.jsonl`; native compilation rebuilt the current
  derived state.
- QMD was the Docker-era memory backend. It was removed from current OpenClaw and
  must not be restored: no `memory.backend: "qmd"` configuration, QMD CLI/indexes,
  GGUF model cache, session exports, or periodic QMD embedding cron were migrated.
  The complete legacy QMD material remains preserved under `.openclaw_BAK`.
- Native `memory-core` is the supported memory engine. Keep keyword/wiki retrieval
  as the baseline; choose a supported embedding provider separately if semantic
  recall is wanted later. Do not treat the retired QMD configuration as a migration
  template.

## Repository tracking

The local repository is `/home/shelldon/.openclaw/`. It tracks setup/configuration
artifacts only — not runtime state or credentials.

Tracked setup artifacts:

- `.gitignore`
- `openclaw.json.example` (redacted configuration template)
- `workspace/` (agent instructions, identity, user model, soul, compact memory
  routing, avatar, and this document)

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

## Deferred re-setup: Clawfred

The Discord and Telegram channels are fully restored, validated, and connected.
Discord is restricted to the configured allowlist of four channels and the owner;
Telegram uses its restored allowlist. The current default agent is `shelldon`.

When Clawfred is deliberately restored, recreate the complete agent as a native
agent rather than copying Docker runtime state wholesale:

1. Create agent ID `clawfred` (display/identity name `Clawfred`) with a native
   workspace at `~/.openclaw/workspace-clawfred`. Restore the legacy workspace
   from `~/.openclaw_BAK/workspace-clawfred/`, including its agent instructions,
   identity, soul, user model, memory, skills, scripts, entities, exports, and
   avatar (`avatars/Cooking-Crab_as_Nutri-Consultant.png`). Review the nested Git
   repository deliberately rather than carrying its old runtime state implicitly.
2. Recreate its current-compatible model and provider authentication deliberately.
   The legacy agent used `opencode-go/deepseek-v4-flash` with NVIDIA fallbacks;
   do not copy its old agent SQLite, session store, credentials, QMD cache, or
   Docker paths into the native agent.
3. Apply its identity theme: “A meticulous digital butler — part crab, part
   database steward, part sysadmin. Sharp-pincered, precise, and impeccably
   organized.”
4. Add the specific Discord binding for `#🍴-nutriclaw`
   (`1524758094079459418`) without removing any existing bindings. Other Discord
   traffic must remain routed to `shelldon`:

   ```json5
   {
     bindings: [
       {
         agentId: "clawfred",
         match: {
           channel: "discord",
           peer: { kind: "channel", id: "1524758094079459418" }
         }
       }
     ]
   }
   ```

5. Validate the configuration, restart the gateway if required, and verify the
   channel binding with a controlled message in `#🍴-nutriclaw`.

## Providers

- The configured default for `shelldon` is `openai/gpt-5.6-luna` with thinking
  `high` and no fallback model.
- Native credential profiles exist for OpenAI (OAuth), NVIDIA (API key), and
  OpenCode Go (API key), stored in the agent SQLite auth store rather than an
  environment file. NVIDIA is used by the Session Cleanup automation.
- The `codex` plugin is enabled and loaded. Use `openclaw models status` before
  changing provider or runtime configuration; it is the live authority for model
  routes and credential usability.
- `web_search` and `web_fetch` are enabled with DuckDuckGo as the key-free search
  provider.
- Legacy provider configuration was not copied wholesale from Docker; restore
  additional providers only through the current native setup flow.

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

## Official OpenClaw backups

Official archives are written to the `shelldon`-owned mount:

```text
/mnt/openclaw-backup
```

It is a bind mount of the OpenClaw folder in the Nextcloud files tree:

```text
/mnt/storagebox-node/nextcloud/data/henning/files/Backup/OpenClaw
```

The StorageBox CIFS mount must use `serverino`, not `noserverino`: the official
archiver verifies hard-link file identity during atomic publication. This was
fixed and the mount, manual archive, and scheduled archive were verified.

The enabled `🦀 OpenClaw Nightly Backup` automation runs at `00:01` daily in
`Europe/Berlin`. It invokes the official command with `--verify` and announces a
concise success status in Discord `#system-status`. The historical custom tar
script remains only under `.openclaw_BAK` and must not be restored.

```bash
# Preview without writing.
openclaw backup create --output /mnt/openclaw-backup --dry-run --json

# Create and immediately verify an archive.
openclaw backup create --output /mnt/openclaw-backup --verify

# Verify an existing archive.
openclaw backup verify /mnt/openclaw-backup/<timestamp>-openclaw-backup.tar.gz

# Inspect the scheduled job or its runs.
openclaw cron get acac3466-9a15-45ab-a223-7be425800984
openclaw cron runs acac3466-9a15-45ab-a223-7be425800984
```

Archives contain sensitive state and credentials. Keep the destination restricted
to `shelldon`; never add archives to Git. `openclaw backup enable` is for
versioned Git backups and is not used for these timestamped archives.

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

1. Deferred native restoration of the `clawfred` agent and its dedicated Discord
   binding, as documented above.
2. Review and selectively clean the restored wiki’s historical Docker/QMD claims;
   see `workspace/backlog_todos.md`.
3. Choose a supported native embedding provider only if semantic memory recall is
   wanted; do not restore QMD.
4. `shelldon` sudo/group privileges for future root-level tasks (to be defined).
