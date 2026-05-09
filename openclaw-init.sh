#!/usr/bin/env sh
set -eu

# Seed the live config dir from the image-baked snapshot (no-clobber for skills).
# Then always merge the clawhub registry so seed skills are properly tracked.
: "${STAGED_SKILLS_DIR:?STAGED_SKILLS_DIR is not set}"
: "${LIVE_SKILLS_DIR:?LIVE_SKILLS_DIR is not set}"

mkdir -p "$LIVE_SKILLS_DIR"
cp -rn "$STAGED_SKILLS_DIR/." "$LIVE_SKILLS_DIR/"
jq -s '{version:1,skills:(.[0].skills*.[1].skills)}' \
  "$STAGED_SKILLS_DIR/.clawhub/lock.json" \
  "$LIVE_SKILLS_DIR/.clawhub/lock.json" \
  > "$LIVE_SKILLS_DIR/.clawhub/lock.json.tmp" \
  && mv "$LIVE_SKILLS_DIR/.clawhub/lock.json.tmp" "$LIVE_SKILLS_DIR/.clawhub/lock.json"

exec docker-entrypoint.sh "$@"
