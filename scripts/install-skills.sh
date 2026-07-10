#!/usr/bin/env bash
# Installs pinned ClawHub skills into the live ~/.openclaw volume via the gateway image.
# Safe to re-run: every run re-installs the pinned version for each skill (idempotent by
# convergence, not by skip-if-present — running it twice in a row is a no-op in effect).
# Run once after `docker compose up -d openclaw-gateway`, and again any time a
# CLAWHUB_*_SKILL_VERSION value changes in .env.

set -euo pipefail

# Read a single key from .env without fully sourcing it (avoids issues with
# special characters in unrelated secret values).
_get_env_value() {
  local key="$1"
  local file="${ENV_FILE:-.env}"
  if [[ -f "$file" ]]; then
    grep -E "^${key}=" "$file" | tail -n1 | cut -d= -f2-
  fi
}

COMPOSE_SERVICE="openclaw-gateway"
HEALTH_URL="http://localhost:${OPENCLAW_GATEWAY_PORT:-18789}/healthz"
HEALTH_TIMEOUT_SECS=60

# owner/slug : version-env-var pairs. Add new lines here to add skills;
# no Dockerfile or rebuild required.
SKILLS=(
  "@steipete/github:CLAWHUB_GITHUB_SKILL_VERSION"
  "@shawnpana/browser-use:CLAWHUB_BROWSER_USE_SKILL_VERSION"
  "@matrixy/agent-browser-clawdbot:CLAWHUB_AGENT_BROWSER_SKILL_VERSION"
  "@asleep123/caldav-calendar:CLAWHUB_CALDAV_CALENDAR_SKILL_VERSION"
)

echo "==> Waiting for ${COMPOSE_SERVICE} to report healthy at ${HEALTH_URL} ..."
elapsed=0
until curl -sf "${HEALTH_URL}" >/dev/null 2>&1; do
  if (( elapsed >= HEALTH_TIMEOUT_SECS )); then
    echo "ERROR: ${COMPOSE_SERVICE} did not become healthy within ${HEALTH_TIMEOUT_SECS}s." >&2
    echo "       Run 'docker compose up -d openclaw-gateway' first, or check 'docker compose logs'." >&2
    exit 1
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done
echo "==> Gateway is healthy."

failures=()

for entry in "${SKILLS[@]}"; do
  slug="${entry%%:*}"
  version_var="${entry##*:}"
  version="$(_get_env_value "$version_var")"

  if [[ -z "${version}" ]]; then
    echo "WARN: ${version_var} is not set in .env — installing ${slug} without a version pin."
    version_args=()
  else
    version_args=(--version "${version}")
  fi

  echo "==> Installing ${slug} ${version:+(${version})} ..."
  if ! docker compose run --rm --no-deps --entrypoint node "${COMPOSE_SERVICE}" \
        dist/index.js skills install "${slug}" "${version_args[@]}" --global --force; then
    echo "ERROR: failed to install ${slug}" >&2
    failures+=("${slug}")
  fi
done

if (( ${#failures[@]} > 0 )); then
  echo "==> Failed skills: ${failures[*]}" >&2
  exit 1
fi

echo "==> All skills installed into the live ~/.openclaw volume."
echo "==> Verify with: docker exec openclaw-openclaw-gateway-1 node dist/index.js skills list"
