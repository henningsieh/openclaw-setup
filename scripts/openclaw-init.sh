#!/usr/bin/env sh
set -eu

# Ensure the live config dir exists. Skills are installed at runtime by
# scripts/install-skills.sh; there is no image-baked seed to copy.
: "${OPENCLAW_DIR:?OPENCLAW_DIR is not set}"
mkdir -p "$OPENCLAW_DIR"

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

# ── Start Xvfb virtual display (enables headed Chrome, bypasses Cloudflare headless detection) ──
if command -v Xvfb >/dev/null 2>&1; then
    export DISPLAY=:99
    Xvfb "$DISPLAY" -screen 0 1920x1080x24 -ac >/dev/null 2>&1 &
    XVFB_PID=$!
    echo "Xvfb started on $DISPLAY (PID $XVFB_PID)"
    
    # Update browser config to run headed (no HeadlessChrome fingerprint)
    if jq -e '.browser.headless' "$OPENCLAW_JSON" > /dev/null 2>&1; then
        jq '.browser.headless = false | .browser.extraArgs = ["--window-size=1920,1080", "--no-first-run", "--no-default-browser-check", "--disable-blink-features=AutomationControlled"]' "$OPENCLAW_JSON" \
            > "$OPENCLAW_JSON.tmp" \
            && mv "$OPENCLAW_JSON.tmp" "$OPENCLAW_JSON"
        echo "Browser config updated: headless=false (via Xvfb)"
    fi
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
# Without this, vault_fetch tool queries (and SecretRef resolution) after a
# container recreate would return stale data because bw list items relies on
# the local cache.
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

# Persist both CardDAV (qcard) and CalDAV (vdirsyncer/khal) credentials to disk
# for agent sessions. The password comes from the Vaultwarden MailCow item that
# has SOGO_EMAIL as its login username, resolved at container startup — never
# stored as an env var (the .env holds SOGO_EMAIL, not the password).
SOGO_BASE_URL="https://mail.sieh.org/SOGo/dav"
: "${SOGO_EMAIL:?SOGO_EMAIL is not set}"

if [ -n "${BW_CLIENTID:-}" ] && [ -n "${BW_CLIENTSECRET:-}" ] && [ -n "${BW_PASSWORD:-}" ]; then
    # Unlock vault and find the MailCow item whose login username matches SOGO_EMAIL
    QCARD_SESSION=$("$BW_BIN" unlock --passwordenv BW_PASSWORD --raw 2>/dev/null) || true
    if [ -n "$QCARD_SESSION" ]; then
        QCARD_PASSWORD=$("$BW_BIN" list items --search "MailCow" --session "$QCARD_SESSION" 2>/dev/null | \
            jq -r --arg user "$SOGO_EMAIL" '.[] | select(.login.username == $user) | .login.password' 2>/dev/null)
        "$BW_BIN" lock --session "$QCARD_SESSION" >/dev/null 2>&1
    fi

    if [ -n "$QCARD_PASSWORD" ] && [ "$QCARD_PASSWORD" != "null" ]; then
        # ── CardDAV (qcard) ────────────────────────────────────────────────
        mkdir -p /home/node/.config/qcard
        jq -n \
            --arg url "${SOGO_BASE_URL}/${SOGO_EMAIL}/Contacts/personal/" \
            --arg user "$SOGO_EMAIL" \
            --arg pass "$QCARD_PASSWORD" \
            '{Addressbooks: [{Url: $url, Username: $user, Password: $pass}], DetailThreshold: 3, SortByLastname: false}' \
            > /home/node/.config/qcard/config.json
        chmod 600 /home/node/.config/qcard/config.json

        # ── CalDAV (vdirsyncer + khal) ────────────────────────────────────
        mkdir -p /home/node/.config/vdirsyncer /home/node/.config/khal \
                 /home/node/.local/share/vdirsyncer/status \
                 /home/node/.local/share/vdirsyncer/calendars/personal
        chmod 700 /home/node/.config/vdirsyncer /home/node/.config/khal

        printf '%s' "$QCARD_PASSWORD" > /home/node/.config/vdirsyncer/caldav_password
        chmod 600 /home/node/.config/vdirsyncer/caldav_password

        cat > /home/node/.config/vdirsyncer/config << VDIRSYNCER
[general]
status_path = "~/.local/share/vdirsyncer/status/"

[pair personal]
a = "personal_remote"
b = "personal_local"
collections = null
conflict_resolution = "a wins"

[storage personal_remote]
type = "caldav"
url = "${SOGO_BASE_URL}/${SOGO_EMAIL}/Calendar/personal/"
username = "${SOGO_EMAIL}"
password.fetch = ["command", "cat", "~/.config/vdirsyncer/caldav_password"]

[storage personal_local]
type = "filesystem"
path = "~/.local/share/vdirsyncer/calendars/personal/"
fileext = ".ics"
VDIRSYNCER

        cat > /home/node/.config/khal/config <<'KHAL'
[calendars]
[[personal]]
path = ~/.local/share/vdirsyncer/calendars/personal/

[default]
highlight_event_days = True

[locale]
timeformat = %H:%M
dateformat = %Y-%m-%d
datetimeformat = %Y-%m-%d %H:%M
longdatetimeformat = %Y-%m-%d %H:%M
local_timezone = Europe/Berlin
default_timezone = Europe/Berlin
KHAL
        chmod 600 /home/node/.config/khal/config

        # Initial discovery + sync so the calendar is queryable right away.
        echo y | vdirsyncer discover personal >/dev/null 2>&1 || true
        vdirsyncer sync >/dev/null 2>&1 || true
    else
        echo "WARNING: qcard/caldav credential lookup failed (no MailCow item with username $SOGO_EMAIL)" >&2
    fi
fi

# Install khal-event wrapper so agent exec callers get atomic create + server sync.
KHAL_EVENT_SRC="${OPENCLAW_DIR}/workspace/openclaw-setup/scripts/khal-event"
KHAL_EVENT_DST=/usr/local/bin/khal-event
if [ -f "$KHAL_EVENT_SRC" ]; then
    cp "$KHAL_EVENT_SRC" "$KHAL_EVENT_DST"
    chmod 755 "$KHAL_EVENT_DST"
    echo "khal-event installed at ${KHAL_EVENT_DST}"
fi

# Refresh persisted plugin registry on every start so the policy hash stays
# current after upgrades. Without this, the CLI falls back to an expensive
# "derived" plugin scan on every invocation (~8s extra per command).
# openclaw plugins registry --refresh >/dev/null 2>&1 || true

command -v docker-entrypoint.sh >/dev/null 2>&1 \
  || { echo "ERROR: docker-entrypoint.sh not found in PATH — base image mismatch?" >&2; exit 1; }
exec docker-entrypoint.sh "$@"
