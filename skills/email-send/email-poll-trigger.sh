#!/usr/bin/env bash
# Poll the shared mailbox without an LLM. Trigger the reply agent only when
# allowlisted unseen mail exists. Silent on empty polls; safe to run every 5m.
set -euo pipefail
export PATH="/home/shelldon/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_JOB_ID="4f9328ac-2501-4961-b5cd-193a1bbbac6d"
LOCK="/tmp/openclaw-email-poll-trigger.lock"

# One poll at a time; a slow agent run must not stack triggers.
exec 9>"$LOCK"
if ! flock -n 9; then
  exit 0
fi

out="$(python3 "$SCRIPT_DIR/email-poll-reply.py" list 2>/dev/null)" || exit 0
count="$(printf '%s' "$out" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d.get("unseen_allowlisted") or []))' 2>/dev/null || echo 0)"

if [ "${count:-0}" -gt 0 ]; then
  openclaw automations run "$AGENT_JOB_ID" >/dev/null 2>&1 || true
fi
exit 0
