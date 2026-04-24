# OpenClaw Gateway — Local Source Build Guide

This repository customises the official OpenClaw Docker setup to support
**locally-built base images**, allowing unmerged upstream PRs to be merged in
before an official release ships them.

The current branch (`feature/local-source-build-pr65561`) ships with PR
[openclaw/openclaw#65561](https://github.com/openclaw/openclaw/pull/65561)
baked in, which fixes
[issue #65548](https://github.com/openclaw/openclaw/issues/65548):
`ERR_MODULE_NOT_FOUND` crashes on every Telegram/Discord message in 2026.4.12.

---

## How it works

The `docker-compose.yml` / `Dockerfile.gateway` accept an `OPENCLAW_BASE_IMAGE`
variable:

| `OPENCLAW_BASE_IMAGE` value | Effect |
|---|---|
| `ghcr.io/openclaw/openclaw` *(default)* | Official release image pulled from GitHub Container Registry |
| `openclaw-patched` | Locally-built image with a PR merged in |

Set this in your `.env` file (which is gitignored and never committed).

---

## Directory layout

```
/root/openclaw/          ← this repository (gateway config + Dockerfiles)
/root/openclaw-src/      ← upstream source clone used to build patched images
```

Images are stored in the **local Docker image store** on the host — they are
not pushed to any registry. Run `docker images | grep openclaw` to list them.

---

## Reproducing a patched build for a future PR

Follow these steps every time you want to apply a new upstream PR.

### Step 1 — Clone / update the upstream source

```bash
# First time only:
git clone https://github.com/openclaw/openclaw.git /root/openclaw-src
cd /root/openclaw-src

# Add the fork that contains the PR (one-time per fork):
git remote add <fork-author> https://github.com/<fork-author>/openclaw.git
```

### Step 2 — Check out the PR branch

```bash
cd /root/openclaw-src

# Fetch the fork's branches:
git fetch <fork-author>

# Check out the PR branch:
git checkout <fork-author>/<pr-branch-name>
```

For PR #65561 the commands were:

```bash
git remote add garnetlyx https://github.com/garnetlyx/openclaw.git
git fetch garnetlyx
git checkout garnetlyx/fix/telegram-discord-crash-runtime-imports
# HEAD → fa3ad7d0
```

### Step 3 — Free disk space before building

The source build produces a ~3 GB image. Clear build cache first to avoid
running out of disk:

```bash
docker builder prune -af
docker image prune -f
df -h /     # confirm at least ~15 GB free
```

### Step 4 — Build the patched base image

Run this from `/root/openclaw-src` (where the upstream `Dockerfile` lives).
Tag it with the same version string you have in your `.env`:

```bash
cd /root/openclaw-src
docker build --no-cache \
  --build-arg OPENCLAW_DOCKER_APT_UPGRADE=0 \
  -t openclaw-patched:2026.4.12 \
  .
```

`OPENCLAW_DOCKER_APT_UPGRADE=0` skips `apt-get upgrade` in the runtime stage
to save ~5 min of build time (optional but recommended).

Build takes roughly **10 minutes**. Verify the fix is present:

```bash
docker run --rm openclaw-patched:2026.4.12 \
  ls /app/dist/ | grep -E "status|commands-status"
# Expected output includes:
#   status.runtime.js
#   commands-status-deps.runtime.js
#   commands-status.runtime.js
```

### Step 5 — Build the gateway image on top of the patched base

```bash
cd /root/openclaw
docker compose build --no-cache openclaw-gateway
```

This produces `openclaw-local:2026.4.12` (the name comes from `OPENCLAW_IMAGE`
in `.env`), layered on top of `openclaw-patched:2026.4.12`.

### Step 6 — Restart and validate

```bash
docker compose up -d openclaw-gateway

# Wait ~20 s, then:
curl http://localhost:18789/healthz
# → {"ok":true,"status":"live"}
```

---

## `.env` reference — switching between images

```dotenv
# Which version tag to use everywhere
OPENCLAW_VERSION=2026.4.12

# The name docker compose uses when tagging the built gateway image
OPENCLAW_IMAGE=openclaw-local

# Base image for Dockerfile.gateway:
#   Official release (default when key is absent):
#     OPENCLAW_BASE_IMAGE=ghcr.io/openclaw/openclaw
#   Locally-built patched image:
#     OPENCLAW_BASE_IMAGE=openclaw-patched
OPENCLAW_BASE_IMAGE=openclaw-patched
```

### Switching back to the official release

Remove (or comment out) `OPENCLAW_BASE_IMAGE` from `.env`, then rebuild:

```bash
# .env: remove or comment out OPENCLAW_BASE_IMAGE
docker compose build --no-cache openclaw-gateway
docker compose up -d openclaw-gateway
```

`docker-compose.yml` defaults to `ghcr.io/openclaw/openclaw` when
`OPENCLAW_BASE_IMAGE` is unset.

### Upgrading to a new official release (e.g. 2026.5.0)

Once the upstream fix ships in an official release you no longer need the
patched image. Just update `.env`:

```dotenv
OPENCLAW_VERSION=2026.5.0
# Remove OPENCLAW_BASE_IMAGE to revert to ghcr.io
```

Then rebuild normally.

### Applying a different / newer PR

Repeat **Steps 1–6** above:
1. Fetch the new PR branch in `/root/openclaw-src`.
2. Rebuild `openclaw-patched:<version>` with `--no-cache`.
3. Rebuild the gateway with `--no-cache`.
4. Restart and validate health.

You can keep multiple patched images side-by-side by using different tags:

```bash
docker build --no-cache -t openclaw-patched-pr99999:2026.4.12 .
# Then in .env:
OPENCLAW_BASE_IMAGE=openclaw-patched-pr99999
```

---

## Current image inventory

| Image | Tag | Description |
|---|---|---|
| `openclaw-patched` | `2026.4.12` | Source build with PR #65561 (Telegram/Discord crash fix) |
| `openclaw-local` | `2026.4.12` | Gateway image built on top of `openclaw-patched` |

Images live only in the local Docker store. They are **not** pushed to any
registry. To save them for transfer or backup:

```bash
docker save openclaw-patched:2026.4.12 | gzip > openclaw-patched-2026.4.12.tar.gz
docker save openclaw-local:2026.4.12   | gzip > openclaw-local-2026.4.12.tar.gz

# Restore on another host:
docker load < openclaw-patched-2026.4.12.tar.gz
```
