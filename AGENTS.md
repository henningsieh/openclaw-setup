# AGENTS.md — Machine-Oriented Guide for openclaw-setup

This file documents the architecture, conventions, and operating procedures for agents (AI or automated) working with this repository.

---

## Repository purpose

This repository extends the official OpenClaw Docker image with:
- Extra system packages, a Go toolchain, and CLI tools baked in at image build time (reproducible, no manual `apt`/`npm` inside the running container)
- A seed skill (`github`) baked into the image and automatically installed on first container start via `openclaw-init.sh`
- Support for swapping the base image between the official release and a locally-built patched image (e.g. testing an upstream PR)

**Golden rule**: everything that should be present in every deployment is configured at Docker build time. Running `clawhub install`, `npm install -g`, or even `python -m pip install` inside the running container is an anti-pattern here.

---

## File map

| File | Role |
|---|---|
| `Dockerfile.gateway` | Defines the gateway image. Eight numbered build steps — see below. |
| `openclaw-init.sh` | Container entrypoint. Seeds skills, merges clawhub registry, execs gateway. |
| `docker-compose.yml` | Orchestrates `openclaw-gateway` (long-lived) + `openclaw-cli` (cli profile) services. |
| `.env` | Local secrets and path overrides — **gitignored, never commit**. |
| `.env.example` | Template with all keys documented. Commit-safe (no real secrets). |
| `README.md` | Human-oriented guide for Docker setup, upgrading, PR-based local builds and image management. |

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
Step 3  COPY openclaw-init.sh → /usr/local/bin/openclaw-entrypoint.sh
        COPY openclaw-bw-resolver.mjs → /usr/local/bin/openclaw-bw-resolver (chmod +x)
        mkdir /opt/openclaw-skills-seed (owned by node)
Step 4  Switch USER node
Step 5  GOPATH=/home/node/go
Step 6  go install ser1.net/qcard@latest
Step 7  npm install -g @xdevplatform/xurl clawhub@latest @steipete/summarize @tobilu/qmd @bitwarden/cli
        (prefix: /home/node/.local — no root required)
Step 8  CLAWHUB_WORKDIR=/opt/openclaw-skills-seed clawhub install github --no-input --force
        (bakes skill files + .clawhub/lock.json into the seed dir)
        ENV CLAWHUB_WORKDIR=/home/node/.openclaw   ← runtime default for interactive use
        ENTRYPOINT ["/usr/local/bin/openclaw-entrypoint.sh"]
```

**Key invariant**: `CLAWHUB_WORKDIR` is overridden inline for step 8 only. At runtime it points to `/home/node/.openclaw` so interactive `clawhub` commands operate on the live volume.

**Skill version note**: ClawHub skill pins like `browser-use` are authoritative from the ClawHub skill registry/page for the owner/slug (for example `https://clawhub.ai/shawnpana/browser-use`). These skill versions are not the same as npm package versions or GitHub repo package metadata, so verify them against the published ClawHub skill listing when checking or updating skill arguments.

### Why tools are installed at build time

- Reproducible: every container start from the same image has identical tooling
- No internet required at runtime
- `go install`, `npm install -g`, and `clawhub install` are all cache-friendly Docker layers — only the changed step and all subsequent steps re-run on rebuild

---

## Skill seeding — how it works

### Build time

```dockerfile
RUN CLAWHUB_WORKDIR=/opt/openclaw-skills-seed \
    clawhub install github --no-input --force
```

This writes into the image layer:
```
/opt/openclaw-skills-seed/
  skills/
    github/       ← skill files
  .clawhub/
    lock.json     ← clawhub registry entry for github
```

### Container start (`openclaw-init.sh`)

Two operations run on every container start before the gateway process:

1. **`cp -rn $STAGED_SKILLS_DIR/. $OPENCLAW_DIR/`** Copies the entire seed dir (skills + `.clawhub/`) into the live host volume. `-n` = no-clobber: skills the user has installed or modified are never overwritten.
2. **`jq -s '{version:1,skills:(.[0].skills*.[1].skills)}'`** Merges the seed lock into the live lock. The seed is `.[0]` (baseline); the live lock is `.[1]` (user wins on key collision). This ensures seed skills are tracked by `clawhub list` exactly as if the user had run `clawhub install github` themselves.

### Result

- `clawhub list` → `github  1.0.0` (tracked, not "Manually installed")
- `clawhub uninstall github --yes` → removes from live dir only; seed in `/opt/openclaw-skills-seed/` is untouched (image layer)
- On next container restart, the skill is automatically re-seeded

### Adding more seed skills

Edit `Dockerfile.gateway` step 8:

```dockerfile
RUN CLAWHUB_WORKDIR=/opt/openclaw-skills-seed \
    clawhub install github another-skill --no-input --force
```

Then rebuild:

```bash
docker compose build openclaw-gateway
```

Or rebuild and restart:

```bash
docker compose up -d --build --force-recreate --no-deps openclaw-gateway
```

---

## Environment variables

All variables are defined in `.env` (never committed) and documented in `example.env`. Key variables:

### Build args (Dockerfile.gateway)

| Variable | Example | Purpose |
|---|---|---|
| `OPENCLAW_VERSION` | `2026.5.18` | Image tag for base and output images |
| `OPENCLAW_BASE_IMAGE` | `ghcr.io/openclaw/openclaw` | Which base image to extend |
| `GO_VERSION` | `1.26.3` | Go toolchain version to install |

### Runtime env (docker-compose → container)

| Variable | Default | Purpose |
|---|---|---|
| `STAGED_SKILLS_DIR` | `/opt/openclaw-skills-seed` | Image-baked seed dir (read-only at runtime) |
| `OPENCLAW_DIR` | `/home/node/.openclaw` | Host-mounted live config dir |
| `CLAWHUB_WORKDIR` | `/home/node/.openclaw` | Where clawhub reads/writes skills interactively |
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

`/home/node/.openclaw` is the single live source of truth inside the container. The seed dir `/opt/openclaw-skills-seed` lives only in the image layer and is never mounted.

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
docker exec openclaw-openclaw-gateway-1 clawhub list
# github  1.0.0
# Manually installed (not tracked by clawhub):
#   <any skills installed outside the seed>
```

### Install additional skills at runtime

```bash
docker exec openclaw-openclaw-gateway-1 clawhub install <slug>
```
This writes to `/home/node/.openclaw/skills/` (the host volume). The skill persists across container restarts but is **not** part of the image — it will be lost if the volume is wiped.

To make a skill permanent (reproducible), add it to step 8 of `Dockerfile.gateway` and rebuild.

### Uninstall a skill

```bash
docker exec openclaw-openclaw-gateway-1 clawhub uninstall <slug> --yes
```
Removes from the live volume only. Seed skills re-appear on next restart.

---

## Common mistakes to avoid

| Mistake | Correct approach |
|---|---|
| Running `npm install -g` inside a running container | Add to `Dockerfile.gateway` step 7 and rebuild |
| Running `clawhub install` inside a running container to "permanently" add a skill | Add to `Dockerfile.gateway` step 8 (`CLAWHUB_WORKDIR=/opt/openclaw-skills-seed`) and rebuild |
| Using `CLAWHUB_WORKDIR=/opt/openclaw-skills-seed` in the `ENV` directive | Use it only as an inline override in the `RUN` step; the `ENV` must stay as `/home/node/.openclaw` |
| Installing system packages with `apt-get` inside the container | Add to `Dockerfile.gateway` step 1 and rebuild |
| Pointing `STAGED_SKILLS_DIR` at the `skills/` subdir | Point at the parent dir (`/opt/openclaw-skills-seed`) so `cp -rn` also copies `.clawhub/lock.json` |
| Expecting `clawhub uninstall` to permanently remove a seed skill | Seed skills re-seed on restart; to truly remove one, delete it from step 8 and rebuild |

---

## Services in docker-compose.yml

### `openclaw-gateway` (long-lived)
Runs as user `node` (UID 1000). Entrypoint is `openclaw-entrypoint.sh` which seeds skills, merges the clawhub registry, then execs `docker-entrypoint.sh` → `node dist/index.js gateway …`.

### `openclaw-cli` (profile: `cli`)
Same image as the gateway, network-mode attached to the gateway service, used for one-shot CLI commands. Only starts when `--profile cli` is passed.
