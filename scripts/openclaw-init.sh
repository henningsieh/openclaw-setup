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
# Uses the private bw path (not on agent exec PATH — see Dockerfile step 7).
BW_BIN=/home/node/.local/lib/bw-private
if [ -n "${BW_SERVER_URL:-}" ]; then
  BW_STATUS=$("$BW_BIN" status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")
  if [ "$BW_STATUS" = "unauthenticated" ]; then
    "$BW_BIN" config server "$BW_SERVER_URL" >/dev/null 2>&1 || true
  fi
fi

# Pre-warm bw CLI cache: login (if needed), sync from server, then lock.
# Without this, vault-fetch queries after a container recreate would return
# stale data because bw list items relies on the local cache.
# The sync credentials are inherited from container env (BW_CLIENTID etc.).
if [ -n "${BW_CLIENTID:-}" ] && [ -n "${BW_CLIENTSECRET:-}" ] && [ -n "${BW_PASSWORD:-}" ]; then
  # Login with API key — idempotent, no-op if already logged in
  "$BW_BIN" login --apikey >/dev/null 2>&1 || true
  # Unlock, sync, lock — forces a full item refresh from the server
  SYNC_SESSION=$("$BW_BIN" unlock --passwordenv BW_PASSWORD --raw 2>/dev/null) || true
  if [ -n "$SYNC_SESSION" ]; then
    "$BW_BIN" sync --session "$SYNC_SESSION" >/dev/null 2>&1 || true
    "$BW_BIN" lock --session "$SYNC_SESSION" >/dev/null 2>&1
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

# Persist qcard CardDAV credentials to disk for agent sessions.
# ~/.config is on the container layer and gets wiped on Docker rebuilds.
# The password is fetched from Vaultwarden at container startup via the
# bw-resolver — never stored as an env var.
QCARD_SERVER_URL="https://mail.sieh.org/SOGo/dav/henning@sieh.org/Contacts/personal/"
QCARD_USERNAME="henning@sieh.org"
QCARD_RESOLVER_ID="openclaw/qcard/henning@sieh.org"

if [ -n "${BW_SERVER_URL:-}" ] && [ -n "${BW_CLIENTID:-}" ] && [ -n "${BW_CLIENTSECRET:-}" ] && [ -n "${BW_PASSWORD:-}" ]; then
    RESOLVER_INPUT=$(printf '{"protocolVersion":1,"provider":"vaultwarden","ids":["%s"]}' "$QCARD_RESOLVER_ID")
    QCARD_PASSWORD=$(echo "$RESOLVER_INPUT" | node /usr/local/bin/openclaw-bw-resolver | jq -r ".values[\"$QCARD_RESOLVER_ID\"]")

    if [ -n "$QCARD_PASSWORD" ] && [ "$QCARD_PASSWORD" != "null" ]; then
        mkdir -p /home/node/.config/qcard
        jq -n \
            --arg url "$QCARD_SERVER_URL" \
            --arg user "$QCARD_USERNAME" \
            --arg pass "$QCARD_PASSWORD" \
            '{Addressbooks: [{Url: $url, Username: $user, Password: $pass}], DetailThreshold: 3, SortByLastname: false}' \
            > /home/node/.config/qcard/config.json
        chmod 600 /home/node/.config/qcard/config.json
    else
        echo "WARNING: qcard credential lookup failed (id: $QCARD_RESOLVER_ID)" >&2
    fi
fi

# ── Persist CalDAV credentials ────────────────────────────────
if [ -n "$QCARD_PASSWORD" ] && [ "$QCARD_PASSWORD" != "null" ]; then
    # Password file + vdirsyncer + khal config dirs
    mkdir -p /home/node/.config/vdirsyncer /home/node/.config/khal /home/node/.local/share/vdirsyncer/status /home/node/.local/share/vdirsyncer/calendars/personal
    chmod 700 /home/node/.config/vdirsyncer /home/node/.config/khal

    printf '%s' "$QCARD_PASSWORD" > /home/node/.config/vdirsyncer/caldav_password
    chmod 600 /home/node/.config/vdirsyncer/caldav_password

    # vdirsyncer config
    cat > /home/node/.config/vdirsyncer/config <<'VDIRSYNCER'
[general]
status_path = "~/.local/share/vdirsyncer/status/"

[pair personal]
a = "personal_remote"
b = "personal_local"
collections = null
conflict_resolution = "a wins"

[storage personal_remote]
type = "caldav"
url = "https://mail.sieh.org/SOGo/dav/henning@sieh.org/Calendar/personal/"
username = "henning@sieh.org"
password.fetch = ["command", "cat", "~/.config/vdirsyncer/caldav_password"]

[storage personal_local]
type = "filesystem"
path = "~/.local/share/vdirsyncer/calendars/personal/"
fileext = ".ics"
VDIRSYNCER

    # khal config
    cat > /home/node/.config/khal/config <<'KHAL'
[calendars]
[[personal]]
path = ~/.local/share/vdirsyncer/calendars/personal/

[default]
highlight_event_days = True

[locale]
timeformat = %H:%M
dateformat = %d.%m.%Y
local_timezone = Europe/Berlin
default_timezone = Europe/Berlin
KHAL
    chmod 600 /home/node/.config/khal/config

    # Initial discovery + sync so the calendar is queryable right away.
    # Without this, the first khal query after a rebuild would see an empty cache.
    echo y | vdirsyncer discover personal >/dev/null 2>&1 || true
    vdirsyncer sync >/dev/null 2>&1 || true
fi

# Refresh persisted plugin registry on every start so the policy hash stays
# current after upgrades. Without this, the CLI falls back to an expensive
# "derived" plugin scan on every invocation (~8s extra per command).
# openclaw plugins registry --refresh >/dev/null 2>&1 || true

command -v docker-entrypoint.sh >/dev/null 2>&1 \
  || { echo "ERROR: docker-entrypoint.sh not found in PATH — base image mismatch?" >&2; exit 1; }
exec docker-entrypoint.sh "$@"
