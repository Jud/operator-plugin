#!/bin/bash
set -euo pipefail

# Operator UserPromptSubmit hook
# Cancels pending speech messages for this session when the user sends a new
# message, so stale agent replies don't play after the conversation moves on.

source "$(dirname "$0")/_common.sh"
[[ -z "$TOKEN" ]] && exit 0
[[ "$HEADLESS" == "true" ]] && exit 0

curl -s -m 5 -o /dev/null \
  -X POST "http://127.0.0.1:7420/hook/prompt-submit" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg sid "$SESSION_NAME" \
    --arg tty "$TTY" \
    '{ "session_id": $sid, "tty": $tty }'
  )" >/dev/null 2>&1 &

exit 0
