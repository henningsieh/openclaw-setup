#!/usr/bin/env sh
set -eu

if command -v dbus-launch >/dev/null 2>&1 && command -v gnome-keyring-daemon >/dev/null 2>&1; then
  if [ -n "${GOG_KEYRING_PASSWORD:-}" ]; then
    eval "$(dbus-launch --sh-syntax)"
    printf '%s\n' "$GOG_KEYRING_PASSWORD" | gnome-keyring-daemon --unlock --components=secrets >/dev/null
  fi
fi

exec "$@"
