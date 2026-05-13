#!/usr/bin/env sh
set -eu

# Seed the live config dir from the image-baked snapshot (no-clobber for skills).
# Then always merge the clawhub registry so seed skills are properly tracked.
: "${STAGED_SKILLS_DIR:?STAGED_SKILLS_DIR is not set}"
: "${OPENCLAW_DIR:?OPENCLAW_DIR is not set}"

mkdir -p "$OPENCLAW_DIR"
cp -rn "$STAGED_SKILLS_DIR/." "$OPENCLAW_DIR/"
jq -s '{version:1,skills:(.[0].skills*.[1].skills)}' \
  "$STAGED_SKILLS_DIR/.clawhub/lock.json" \
  "$OPENCLAW_DIR/.clawhub/lock.json" \
  > "$OPENCLAW_DIR/.clawhub/lock.json.tmp" \
  && mv "$OPENCLAW_DIR/.clawhub/lock.json.tmp" "$OPENCLAW_DIR/.clawhub/lock.json"

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

# Authenticate gh CLI with a classic GitHub token from the .env file.
if [ -n "${GITHUB_TOKEN}" ]; then
    printf '%s' "$GITHUB_TOKEN" | gh auth login --with-token >/dev/null 2>&1 || true
fi

exec docker-entrypoint.sh "$@"
