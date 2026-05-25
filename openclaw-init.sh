#!/usr/bin/env sh
set -eu

# Seed the live config dir from the image-baked snapshot (no-clobber for skills).
# Then always merge the clawhub registry so seed skills are properly tracked.
: "${STAGED_SKILLS_DIR:?STAGED_SKILLS_DIR is not set}"
: "${OPENCLAW_DIR:?OPENCLAW_DIR is not set}"

mkdir -p "$OPENCLAW_DIR"
cp -rn "$STAGED_SKILLS_DIR/." "$OPENCLAW_DIR/"
jq -s '{version:1,skills:((.[0].skills//{})*((.[1].skills)//{})) }' \
  "$STAGED_SKILLS_DIR/.clawhub/lock.json" \
  "$OPENCLAW_DIR/.clawhub/lock.json" \
  > "$OPENCLAW_DIR/.clawhub/lock.json.tmp" \
  && mv "$OPENCLAW_DIR/.clawhub/lock.json.tmp" "$OPENCLAW_DIR/.clawhub/lock.json"

# Clean up stale Chrome singleton locks from unclean shutdowns
rm -f "$OPENCLAW_DIR/browser/openclaw/user-data/SingletonLock" \
      "$OPENCLAW_DIR/browser/openclaw/user-data/SingletonSocket" \
      "$OPENCLAW_DIR/browser/openclaw/user-data/SingletonCookie" 2>/dev/null || true

# Bootstrap browser defaults for Docker on first start (no-clobber: only if
# openclaw.json has no "browser" key yet, so user edits are never overwritten).
OPENCLAW_JSON="$OPENCLAW_DIR/openclaw.json"
BROWSER_DEFAULTS='{"enabled":true,"executablePath":"/usr/bin/google-chrome-stable","headless":true,"noSandbox":true,"extraArgs":["--disable-gpu","--disable-dev-shm-usage","--disable-software-rasterizer"]}'
if [ ! -f "$OPENCLAW_JSON" ]; then
  printf '{"browser":%s}\n' "$BROWSER_DEFAULTS" > "$OPENCLAW_JSON"
elif ! jq -e '.browser' "$OPENCLAW_JSON" > /dev/null 2>&1; then
  jq --argjson b "$BROWSER_DEFAULTS" '.browser = $b' "$OPENCLAW_JSON" \
    > "$OPENCLAW_JSON.tmp" \
    && mv "$OPENCLAW_JSON.tmp" "$OPENCLAW_JSON"
fi

# Configure Vaultwarden server URL for bw CLI — only when not yet authenticated,
# because bw rejects server changes while a login session is active.
if [ -n "${BW_SERVER_URL:-}" ]; then
  BW_STATUS=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")
  if [ "$BW_STATUS" = "unauthenticated" ]; then
    bw config server "$BW_SERVER_URL" >/dev/null 2>&1 || true
  fi
fi

# Persist gh auth to disk for agent sessions.
# OpenClaw strips GITHUB_TOKEN from exec env, but file-based auth survives.
# No gh CLI call = no network validation = no failure at startup.
if [ -n "${GITHUB_TOKEN}" ]; then
    mkdir -p /home/node/.config/gh
    cat > /home/node/.config/gh/hosts.yml <<EOF
github.com:
    oauth_token: ${GITHUB_TOKEN}
    git_protocol: https
EOF
    chmod 600 /home/node/.config/gh/hosts.yml
fi

# Refresh persisted plugin registry on every start so the policy hash stays
# current after upgrades. Without this, the CLI falls back to an expensive
# "derived" plugin scan on every invocation (~8s extra per command).
openclaw plugins registry --refresh >/dev/null 2>&1 || true

command -v docker-entrypoint.sh >/dev/null 2>&1 \
  || { echo "ERROR: docker-entrypoint.sh not found in PATH — base image mismatch?" >&2; exit 1; }
exec docker-entrypoint.sh "$@"
