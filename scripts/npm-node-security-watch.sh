#!/usr/bin/env bash
# Read-only watchdog: does the official Nginx Proxy Manager image ship a Node.js
# build with the October 2026 security fixes (>= 22.23.4 on the 22.x line)?
# Never touches production containers/data: verification runs in a disposable
# container with --network none and no mounts.
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:/home/shelldon/.npm-global/bin"

IMAGE="jc21/nginx-proxy-manager"
TAG="latest"
STATE="$HOME/.openclaw/workspace/nginx-proxy-manager-node-watch.state.json"
ISSUE="https://github.com/NginxProxyManager/nginx-proxy-manager/issues/5962"
MIN_NODE="22.23.4"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "https://hub.docker.com/v2/repositories/${IMAGE}/tags/${TAG}" >"$tmp/tag.json"
curl -fsSL "https://api.github.com/repos/NginxProxyManager/nginx-proxy-manager/releases/latest" >"$tmp/release.json"
curl -fsSL "https://api.github.com/repos/NginxProxyManager/nginx-proxy-manager/issues/5962" >"$tmp/issue.json"

read -r digest tag_name updated_at < <(python3 - "$tmp/tag.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(d.get("digest",""), d.get("name",""), d.get("last_updated",""))
PY
)

read -r rel_tag rel_date < <(python3 - "$tmp/release.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(d.get("tag_name",""), (d.get("published_at") or "")[:10])
PY
)

read -r issue_state issue_updated < <(python3 - "$tmp/issue.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(d.get("state",""), (d.get("updated_at") or "")[:10])
PY
)

prev_digest=""
prev_node=""
prev_verified_at=""
if [ -f "$STATE" ]; then
  read -r prev_digest prev_node prev_verified_at < <(python3 - "$STATE" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
except Exception:
    d={}
print(d.get("digest",""), d.get("node",""), d.get("verifiedAt",""))
PY
)
fi

verified="nein"
verified_at="$prev_verified_at"
node_version="$prev_node"
if [ -n "$digest" ] && { [ "$digest" != "$prev_digest" ] || [ -z "$prev_node" ] || [ -z "$prev_verified_at" ]; }; then
  sudo -n docker pull "${IMAGE}:${TAG}" >/dev/null 2>&1
  node_version=$(sudo -n docker run --rm --network none --entrypoint node "${IMAGE}:${TAG}" -v 2>/dev/null | tr -d '[:space:]')
  verified="ja"
  verified_at=$(date '+%Y-%m-%d %H:%M %Z')
fi

status="unklar"
if [ -n "$node_version" ]; then
  bare=${node_version#v}
  if [ "$(printf '%s\n%s\n' "$MIN_NODE" "$bare" | sort -V | tail -1)" = "$bare" ]; then
    status="gepatcht"
  else
    status="ungepatcht"
  fi
fi

python3 - "$STATE" "$digest" "$node_version" "$verified_at" <<'PY'
import json,sys,datetime
p,digest,node,verified_at=sys.argv[1:5]
json.dump({"digest":digest,"node":node,"verifiedAt":verified_at,"checkedAt":datetime.datetime.now().astimezone().isoformat(timespec="seconds")},open(p,"w"))
PY

if [ "$status" = "gepatcht" ]; then
  echo "✅ NPM Node-Security-Check: Image ist gepatcht"
  echo "Image: ${IMAGE}:${TAG} (${tag_name}), Digest ${digest:0:19}…"
  echo "Node im Image: ${node_version} (Soll ≥ ${MIN_NODE}); direkt verifiziert: ${verified}${verified_at:+ (${verified_at})}"
else
  echo "🛡️ NPM Node-Security-Check: noch ungepatcht"
  echo "Image: ${IMAGE}:${TAG} (${tag_name}), Digest ${digest:0:19}…"
  echo "Node im Image: ${node_version:-unbekannt} — Soll ≥ ${MIN_NODE}; direkt verifiziert: ${verified}${verified_at:+ (${verified_at})}"
fi
echo "Upstream: neuestes Release ${rel_tag} (${rel_date}); Issue #5962 ${issue_state} (aktualisiert ${issue_updated})"
echo "Quelle: https://hub.docker.com/r/${IMAGE}/tags und ${ISSUE}"
echo "Aktion: keine (nur Read-only-Check)"
