#!/usr/bin/env sh
set -eu

# Merge baked-in default skills into the live mounted workspace.
: "${STAGED_SKILLS_DIR:?STAGED_SKILLS_DIR is not set}"
: "${LIVE_SKILLS_DIR:?LIVE_SKILLS_DIR is not set}"

if [ -d "$STAGED_SKILLS_DIR" ]; then
  mkdir -p "$LIVE_SKILLS_DIR"
  cp -rn "$STAGED_SKILLS_DIR/." "$LIVE_SKILLS_DIR/"
  chown -R node:node "$LIVE_SKILLS_DIR"
fi

if command -v dbus-launch >/dev/null 2>&1 && command -v gnome-keyring-daemon >/dev/null 2>&1; then
  if [ -n "${GOG_KEYRING_PASSWORD:-}" ]; then
    eval "$(dbus-launch --sh-syntax)"
    printf '%s\n' "$GOG_KEYRING_PASSWORD" | gnome-keyring-daemon --unlock --components=secrets >/dev/null
  fi
fi

exec docker-entrypoint.sh "$@"
