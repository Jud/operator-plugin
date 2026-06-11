#!/bin/bash
set -euo pipefail

# Operator Stop hook
# Posts the last assistant message to the Operator daemon for routing context
# and as fallback speech delivery.

source "$(dirname "$0")/_common.sh"
[[ -z "$TOKEN" ]] && exit 0
[[ "$HEADLESS" == "true" ]] && exit 0

LAST_MSG=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // ""')

# POST stop event to Operator daemon (best-effort, fire-and-forget)
curl -s -m 5 -o /dev/null \
  -X POST "http://127.0.0.1:7420/hook/stop" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg sid "$SESSION_NAME" \
    --arg tty "$TTY" \
    --arg msg "$LAST_MSG" \
    '{ "session_id": $sid, "tty": $tty, "last_assistant_message": $msg }'
  )" >/dev/null 2>&1 &

exit 0
