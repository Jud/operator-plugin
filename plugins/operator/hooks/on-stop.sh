#!/bin/bash
set -euo pipefail

# Operator Stop hook
# Posts the last assistant message to the Operator daemon for routing context
# and as fallback speech delivery.

source "$(dirname "$0")/_common.sh"
[[ -z "$TOKEN" ]] && exit 0

LAST_MSG=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // ""')

# POST stop event to Operator daemon (best-effort)
curl -s -o /dev/null -w "" \
  -X POST "http://127.0.0.1:7420/hook/stop" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg sid "$SESSION_NAME" \
    --arg tty "$TTY" \
    --arg msg "$LAST_MSG" \
    '{ "session_id": $sid, "tty": $tty, "last_assistant_message": $msg }'
  )" 2>/dev/null || true

exit 0
