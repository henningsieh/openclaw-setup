# OpenClaw Gateway — Local Source Build Guide

This repository customises the official OpenClaw Docker setup to support
**locally-built base images**. The goal is to let you run a gateway image based on upstream OpenClaw source changes, such as an unmerged pull equest from the official repository or a fork, before those changes ship in an official container release.

Use this when you need to validate or temporarily adopt an upstream fix, feature, or runtime change while still keeping your gateway deployment based on the standard OpenClaw image layout.

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

## Building a customized image from an upstream PR

Follow these steps whenever you want to build from an upstream pull request or another source branch derived from the official OpenClaw repository.

### Step 1 — Clone / update the upstream source

```bash
# First time only:
git clone https://github.com/openclaw/openclaw.git /root/openclaw-src
cd /root/openclaw-src

# Add the remote that contains the PR branch (one-time per fork or mirror):
git remote add <fork-author> https://github.com/<fork-author>/openclaw.git
```

### Step 2 — Check out the PR source branch

```bash
cd /root/openclaw-src

# Fetch the remote's branches:
git fetch <fork-author>

# Check out the branch that contains the PR changes:
git checkout <fork-author>/<pr-branch-name>
```

Alternative, if the PR branch still exists on GitHub and you prefer fetching by PR number:

```bash
git fetch origin pull/<pr-number>/head:pr-<pr-number>
git checkout pr-<pr-number>
```

Example: For PR #65561 the commands were:

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
  -t openclaw-patched:${OPENCLAW_VERSION} \
  .
```

`OPENCLAW_DOCKER_APT_UPGRADE=0` skips `apt-get upgrade` in the runtime stage
to save ~5 min of build time (optional but recommended).

Build takes roughly **10 minutes**. Validate that the expected change is present by running whatever narrow check matches the PR you are testing. For example, if the change adds or renames runtime bundles, you can inspect the generated files:

```bash
docker run --rm openclaw-patched:${OPENCLAW_VERSION} \
  ls /app/dist/ | grep -E "status|commands-status"
# Expected output includes:
#   status.runtime.js
#   commands-status-deps.runtime.js
#   commands-status.runtime.js
```

Other useful validation patterns:

```bash
# Check that a dependency or tool exists:
docker run --rm openclaw-patched:${OPENCLAW_VERSION} command -v <binary>

# Check that a known file from the PR is present:
docker run --rm openclaw-patched:${OPENCLAW_VERSION} ls /app/dist/<path>

# Run a focused CLI command inside the built image:
docker run --rm openclaw-patched:${OPENCLAW_VERSION} node dist/index.js --help
```

### Step 5 — Build the gateway image on top of the patched base

```bash
cd /root/openclaw
docker compose build --no-cache openclaw-gateway
```

This produces `openclaw-local:${OPENCLAW_VERSION}` (the name comes from `OPENCLAW_IMAGE` in `.env`), layered on top of `openclaw-patched:${OPENCLAW_VERSION}`.

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
OPENCLAW_VERSION=<release-version>

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

### Upgrading to a new official release

Once the upstream fix ships in an official release you no longer need the
patched image. Just update `.env`:

```dotenv
OPENCLAW_VERSION=<new-release-version>
# Remove OPENCLAW_BASE_IMAGE to revert to ghcr.io
```

Then rebuild normally.

### Applying a different or newer PR

Repeat **Steps 1–6** above:
1. Fetch the new PR branch in `/root/openclaw-src`.
2. Rebuild `openclaw-patched:<version>` with `--no-cache`.
3. Rebuild the gateway with `--no-cache`.
4. Restart and validate health.

You can keep multiple patched images side-by-side by using different tags:

```bash
docker build --no-cache -t openclaw-patched-pr99999:${OPENCLAW_VERSION} .
# Then in .env:
OPENCLAW_BASE_IMAGE=openclaw-patched-pr99999
```

---

## Image size breakdown

The gateway image (`openclaw-local`) is noticeably larger than the official
base image it builds on top of. Here is why, broken down by `Dockerfile.gateway`
step (measured with `docker history`):

| `Dockerfile.gateway` step | Layer size | What it adds |
|---|---|---|
| `npm install -g clawhub xurl @steipete/summarize @tobilu/qmd` | **~1.1 GB** | npm packages + their full dependency trees; `clawhub` alone pulls in a large transitive closure |
| Go toolchain (`go1.24.1.linux-amd64.tar.gz`) | **~253 MB** | The entire Go standard library, compiler, and tools under `/usr/local/go` |
| `go install sogcli` | **~136 MB** | Compiled `sog` binary **plus** the Go module download cache left in `$GOPATH/pkg/mod` |
| `apt-get install` (gh, git, gnome-keyring, dbus-x11, ripgrep, jq, curl, gnupg, ca-certificates) | **~133 MB** | System-level tooling not present in the Node base image |
| `clawhub install sogcli` (skill staging) | **< 1 MB** | A handful of text/YAML files |
| **Total added by this repo** | **~1.62 GB** | |

For comparison, expect the locally built gateway image to be larger than the official base image with the same tag, because this repository adds extra system packages, a Go toolchain, and globally installed Node.js tools on top of the upstream image.

**Why the npm layer is so large** — `npm install -g` runs as a single `RUN`
statement, so Docker stores the entire post-install filesystem delta as one
opaque layer. Even `npm cache clean --force` at the end does not shrink the
layer because Docker captures the layer *after* the cache is cleared; the
packages themselves (source maps, types, transitive dependencies of
`clawhub@latest`) account for the bulk.

**Why the Go module cache is not cleaned** — `go install` downloads sources
into `$GOPATH/pkg/mod` before compiling. Only the resulting binary ends up in
`$GOPATH/bin/sog`, but the cached sources stay in the layer. Adding
`&& rm -rf /home/node/go/pkg/mod` to step 6 in `Dockerfile.gateway` would
recover ~100 MB.

**How to inspect layers yourself**:

```bash
docker history openclaw-local:<tag> --format "table {{.CreatedBy}}\t{{.Size}}"
```

---

## Current image inventory

| Image | Role | Description |
|---|---|---|
| `openclaw-patched` | patched base image | Locally built OpenClaw base image containing upstream source changes from a PR branch or another custom source branch |
| `openclaw-local` | gateway image | Gateway image built on top of the patched base image using this repository's Dockerfile and Compose setup |

Images live only in the local Docker store. They are **not** pushed to any
registry. To save them for transfer or backup:

```bash
docker save openclaw-patched:${OPENCLAW_VERSION} | gzip > openclaw-patched-${OPENCLAW_VERSION}.tar.gz
docker save openclaw-local:${OPENCLAW_VERSION}   | gzip > openclaw-local-${OPENCLAW_VERSION}.tar.gz

# Restore on another host:
docker load < openclaw-patched-${OPENCLAW_VERSION}.tar.gz
```
