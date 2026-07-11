# AGENTS.md — Machine-Oriented Guide for openclaw-setup

This file documents the architecture, conventions, and operating procedures for agents (AI or automated) working with this repository.

---

## Repository purpose

This repository extends the official OpenClaw Docker image with:
- Extra system packages, a Go toolchain, and CLI tools baked in at image build time (reproducible, no manual `apt`/`npm` inside the running container)
- Support for swapping the base image between the official release and a locally-built patched image (e.g. testing an upstream PR)
- An idempotent `scripts/install-skills.sh` that installs pinned ClawHub skills into the live, host-mounted `~/.openclaw` volume after the gateway container starts

**Golden rule**: *system dependencies* — anything that must be present in every deployment regardless of user configuration — are baked into the image at Docker build time. This includes system packages, the Go toolchain, global npm CLIs, and the `clawhub` CLI itself. *User/deployment configuration* — ClawHub skills, channel tokens, Claude CLI login state, and Vaultwarden credentials — lives on the persisted host volume and is applied at runtime. Running `npm install -g` or `apt-get install` inside a running container is an anti-pattern; running the provided skill installer (or the equivalent `node dist/index.js skills install --global`) against the live volume is the intended pattern.

---

## File map

| File | Role |
|---|---|
| `Dockerfile.gateway` | Defines the gateway image. Seven numbered build steps — see below. |
| `scripts/openclaw-init.sh` | Container entrypoint. Prepares the live config dir, persists credentials, execs the gateway. |
| `scripts/install-skills.sh` | Idempotent post-start skill installer; run once after `docker compose up -d openclaw-gateway`, and again when skill versions change. |
| `docker-compose.yml` | Orchestrates `openclaw-gateway` (long-lived) + `openclaw-cli` (cli profile) services. |
| `.env` | Local secrets and path overrides — **gitignored, never commit**. |
| `.env.example` | Template with all keys documented. Commit-safe (no real secrets). |
| `README.md` | Human-oriented guide for Docker setup, upgrading, PR-based local builds and image management. |
| `plugins/vault-fetch/` | OpenClaw tool plugin that exposes the `vault_fetch` agent tool for Vaultwarden credentials. The shared `bw` auth/unlock/fetch/lock logic lives in `src/bw-client.ts` and is also imported (as compiled `dist/bw-client.js`) by the resolver. |
| `scripts/vaultwarden/` | Vaultwarden exec SecretRef protocol handler (`openclaw-bw-resolver.mjs`) and integration docs. |

---

## Build architecture

### Dockerfile.gateway — step summary

```
Step 1  apt-get: system packages — two passes:
          Pass A (main block): jq, ripgrep, git, curl, gnupg, ca-certificates, gh,
                  util-linux, iproute2, nmap, htop, dstat, glances, strace, sysstat,
                  iperf3, socat, hping3, arp-scan, iftop, nethogs,
                  lsof, ncdu, lshw, dmidecode, hdparm, xxd,
                  ldap-utils, smbclient, krb5-user,
                  snmp, openssl, gnutls-bin, python3, python3-pip, nano, …
          Pass B (optional): snmp-mibs-downloader (non-free; silently skipped if unavailable)
Step 2  Go toolchain: installed at /usr/local/go (version from GO_VERSION arg)
Step 3  COPY scripts/openclaw-init.sh → /usr/local/bin/openclaw-entrypoint.sh
        COPY scripts/vaultwarden/openclaw-bw-resolver.mjs → /usr/local/bin/openclaw-bw-resolver (chmod +x)
        (the legacy openclaw-vault-fetch shell bridge has been removed; agent
         credential access is now the native vault_fetch tool plugin — step 8)
Step 4  Switch USER node
Step 5  GOPATH=/home/node/go
Step 6  go install ser1.net/qcard@${QCARD_VERSION}
Step 7  npm install -g @xdevplatform/xurl clawhub@${CLAWHUB_CLI_VERSION} @steipete/summarize
              @tobilu/qmd @bitwarden/cli browser-use@${BROWSER_USE_CLI_VERSION}
        (prefix: /home/node/.local — no root required)
        ENTRYPOINT ["/usr/local/bin/openclaw-entrypoint.sh"]
Step 8  Build the vault-fetch tool plugin (plugins/vault-fetch/ → tsc →
        openclaw plugins build/validate → npm prune → symlink openclaw→/app)
        at /home/node/.openclaw-plugin-vault-fetch, registered in openclaw.json
        via plugins.load.paths + plugins.entries["vault-fetch"].enabled.
        Exposes the vault_fetch({name, mode?}) agent tool for on-demand
        Vaultwarden credential access. The shared bw auth/unlock/fetch/lock
        logic lives in src/bw-client.ts and is compiled to dist/bw-client.js;
        scripts/vaultwarden/openclaw-bw-resolver.mjs imports that compiled
        module at runtime so resolver + tool plugin stay in sync.
        Runs in-process (process.env.BW_*), no /proc/1/environ and no
        reliance on the exec-env stripping patch.
```

**Skill version note**: ClawHub skill pins like `browser-use` are authoritative from the ClawHub skill registry/page for the owner/slug (for example `https://clawhub.ai/shawnpana/browser-use`). These skill versions are not the same as npm package versions or GitHub repo package metadata, so verify them against the published ClawHub skill listing when checking or updating skill arguments.

### Why tools are installed at build time

- Reproducible: every container start from the same image has identical tooling
- No internet required at runtime for system tooling
- `go install` and `npm install -g` are cache-friendly Docker layers — only the changed step and all subsequent steps re-run on rebuild

---

## Skill installation (runtime)

Skills are installed into the live, host-mounted `~/.openclaw` volume by `scripts/install-skills.sh` *after* the gateway container is healthy. There is no image-baked seed directory, no copy step on container start, and no lock-file merge, because the installed skills live in only one place: the persisted host volume.

### `scripts/install-skills.sh`

- Waits for `openclaw-gateway` to report healthy at `http://localhost:${OPENCLAW_GATEWAY_PORT:-18789}/healthz`.
- For each pinned skill in the `SKILLS` array, runs:
  ```bash
  docker compose run --rm --no-deps --entrypoint node openclaw-gateway \
    dist/index.js skills install @owner/slug --version <version> --global --no-input --force
  ```
- `--global` installs into the shared managed skills directory (`/home/node/.openclaw/skills` inside the container, i.e. `OPENCLAW_CONFIG_DIR/skills` on the host).
- `--no-input --force` makes the install non-interactive and idempotent.
- Version pins come from `CLAWHUB_*_SKILL_VERSION` variables in `.env`.

### When to run it

- Once after the very first `docker compose up -d openclaw-gateway`.
- Again after any `CLAWHUB_*_SKILL_VERSION` value changes in `.env`.
- It is safe to re-run at any time; installing the same pinned version twice is effectively a no-op.

### Adding or removing skills

Edit the `SKILLS` array in `scripts/install-skills.sh`:

```bash
SKILLS=(
  "@steipete/github:CLAWHUB_GITHUB_SKILL_VERSION"
  "@shawnpana/browser-use:CLAWHUB_BROWSER_USE_SKILL_VERSION"
  # add new "@owner/slug:VAR_NAME" lines here
)
```

No Dockerfile change and no image rebuild are required. Run `scripts/install-skills.sh` again to apply the change.

---

## Environment variables

All variables are defined in `.env` (never committed) and documented in `example.env`. Key variables:

### Build args (Dockerfile.gateway)

| Variable | Example | Purpose |
|---|---|---|
| `OPENCLAW_VERSION` | `2026.5.18` | Image tag for base and output images |
| `OPENCLAW_BASE_IMAGE` | `ghcr.io/openclaw/openclaw` | Which base image to extend |
| `GO_VERSION` | `1.26.3` | Go toolchain version to install |
| `QCARD_VERSION` | *(version pin)* | `go install ser1.net/qcard@…` version |
| `CLAWHUB_CLI_VERSION` | `latest` | `clawhub` CLI version installed globally |
| `BROWSER_USE_CLI_VERSION` | `0.7.1` | `browser-use` CLI version installed globally |

### Skill install script (`scripts/install-skills.sh`)

These variables are no longer build args. They are read at runtime by `scripts/install-skills.sh` and passed as `--version` arguments to `node dist/index.js skills install`.

| Variable | Example | Purpose |
|---|---|---|
| `CLAWHUB_GITHUB_SKILL_VERSION` | `1.0.0` | Pin for `@steipete/github` |
| `CLAWHUB_BROWSER_USE_SKILL_VERSION` | `2.0.1` | Pin for `@shawnpana/browser-use` |
| `CLAWHUB_AGENT_BROWSER_SKILL_VERSION` | `0.1.0` | Pin for `@matrixy/agent-browser-clawdbot` |
| `CLAWHUB_CALDAV_CALENDAR_SKILL_VERSION` | `1.0.1` | Pin for `@asleep123/caldav-calendar` |

### Runtime env (docker-compose → container)

| Variable | Default | Purpose |
|---|---|---|
| `OPENCLAW_DIR` | `/home/node/.openclaw` | Host-mounted live config dir |
| `OPENCLAW_CONFIG_DIR` | `/home/shelldon/.openclaw` | Host path mounted to `/home/node/.openclaw` — see note below |
| `OPENCLAW_WORKSPACE_DIR` | `/home/shelldon/.openclaw/workspace` | Host path for workspace — see note below |
| `NODE_COMPILE_CACHE` | `/var/tmp/openclaw-compile-cache` | V8 compile cache (version-stamped) |
| `XDG_CONFIG_HOME` | `/home/node/.openclaw` | XDG config override inside container |
| `OPENCLAW_GATEWAY_TOKEN` | *(secret)* | Bearer token for gateway API auth |
| `GATEWAY_AUTH_PASSWORD` | *(secret)* | Web UI password |

### API keys passed through to the gateway

`COPILOT_GITHUB_TOKEN`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY`, `NVIDIA_API_KEY`, `OPENCODE_API_KEY`, `TELEGRAM_BOT_TOKEN`, `DISCORD_BOT_TOKEN`

### Vaultwarden bootstrap credentials (secrets provider)

| Variable | Purpose |
|---|---|
| `BW_SERVER_URL` | Vaultwarden base URL (e.g. `https://vault.example.com`) |
| `BW_CLIENTID` | API client_id from Vaultwarden → Account Settings → Security → API Key |
| `BW_CLIENTSECRET` | API client_secret (same source) |
| `BW_PASSWORD` | Master password used to unlock the vault |

These are injected via `.env` → `env_file` in `docker-compose.yml` and passed to the resolver subprocess via `passEnv`. They are **never** stored in `openclaw.json`. Leave them empty to disable the Vaultwarden provider.

⚠️ Runtime boundary note: this is a convenience/runtime integration, not a hard isolation boundary. If Vaultwarden auth material is available to the long-lived gateway/container process, treat it as potentially recoverable by code running in that same environment.

---

## Volume layout

```
Host path                              → Container path
/home/shelldon/.openclaw               → /home/node/.openclaw   (config + skills)
/home/shelldon/.openclaw/workspace     → /home/node/.openclaw/workspace
/var/tmp/openclaw-compile-cache/…      → /var/tmp/openclaw-compile-cache/…
```

**Non-default host path**: the config tree lives under `/home/shelldon/` rather than `/root/`. System user `shelldon` holds uid/gid `1000:1000`, matching the container's `node` user. Files written by the container are therefore owned by `shelldon` (not `root`), which means you can SSH in as `shelldon` and work in the config dir without permission conflicts. On a root-only server use `/root/.openclaw[/workspace]` instead.

`/home/node/.openclaw` is the single live source of truth inside the container. Skills live in `/home/node/.openclaw/skills` (i.e. `OPENCLAW_CONFIG_DIR/skills` on the host) and are installed at runtime; nothing skill-related is baked into the image.

---

## Rebuilding

### Rebuild

Use the same canonical command for all rebuilds:

```bash
docker compose up -d --build --force-recreate --no-deps openclaw-gateway
```


### Health check

```bash
curl -sf http://localhost:18789/healthz
# → {"ok":true,"status":"live"}
```
Or via the compose healthcheck (waits for healthy state):

```bash
docker compose ps openclaw-gateway
```

---

## Skill management

### Verify installed skills

```bash
docker exec openclaw-openclaw-gateway-1 node dist/index.js skills list
# github  1.0.0
# browser-use  2.0.1
# agent-browser-clawdbot  0.1.0
# caldav-calendar  1.0.1
```

### Install skills (canonical way)

```bash
./scripts/install-skills.sh
```

This installs every skill defined in the script's `SKILLS` array into the host-mounted `~/.openclaw/skills` directory via `--global`. It is the correct and permanent way to add skills: because the skills live on the persisted volume, they survive container restarts and image rebuilds automatically.

### Install a single skill manually

```bash
docker exec openclaw-openclaw-gateway-1 node dist/index.js skills install @owner/slug --global --no-input --force
```

This writes to `/home/node/.openclaw/skills/` (the host volume) and persists across restarts.

### Uninstall a skill

```bash
docker exec openclaw-openclaw-gateway-1 node dist/index.js skills uninstall @owner/slug --yes
```

Removes from the live volume. To make the uninstall stick after a future `scripts/install-skills.sh` run, remove the corresponding entry from the script's `SKILLS` array as well.

---

## Common mistakes to avoid

| Mistake | Correct approach |
|---|---|
| Running `npm install -g` inside a running container | Add to `Dockerfile.gateway` step 7 and rebuild |
| Installing system packages with `apt-get` inside the container | Add to `Dockerfile.gateway` step 1 and rebuild |
| Adding a skill by editing `Dockerfile.gateway` | Add the skill to `scripts/install-skills.sh` and run it; skills are runtime configuration, not image layers |
| Expecting skills to survive a wiped `~/.openclaw` volume | Skills are persisted only on the host-mounted volume; back up `OPENCLAW_CONFIG_DIR` |

---

## Services in docker-compose.yml

### `openclaw-gateway` (long-lived)
Runs as user `node` (UID 1000). Entrypoint is `openclaw-entrypoint.sh` (copied from `scripts/openclaw-init.sh`), which prepares the live config dir, persists credentials, then execs `docker-entrypoint.sh` → `node dist/index.js gateway …`.

### `openclaw-cli` (profile: `cli`)
Same image as the gateway, network-mode attached to the gateway service, used for one-shot CLI commands. Only starts when `--profile cli` is passed.
