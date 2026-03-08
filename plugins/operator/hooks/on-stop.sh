#!/bin/bash
set -euo pipefail

# Operator Stop hook
# Posts the last assistant message to the Operator daemon as fallback speech
# delivery in case the agent did not call the speak MCP tool.

HOOK_INPUT=$(cat)

SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
LAST_MSG=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // ""')

# Detect TTY of the parent shell
TTY=$(ps -o tty= -p $PPID 2>/dev/null | tr -d '[:space:]') || true
if [[ -z "$TTY" ]]; then
  TTY="unknown"
else
  case "$TTY" in
    /dev/*) ;;
    *) TTY="/dev/$TTY" ;;
  esac
fi

# Read bearer token
TOKEN_FILE="$HOME/.operator/token"
if [[ ! -f "$TOKEN_FILE" ]]; then
  exit 0
fi
TOKEN=$(cat "$TOKEN_FILE")

# POST stop event to Operator daemon (best-effort)
curl -s -o /dev/null -w "" \
  -X POST "http://127.0.0.1:7420/hook/stop" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg sid "$SESSION_ID" \
    --arg tty "$TTY" \
    --arg msg "$LAST_MSG" \
    '{ "session_id": $sid, "tty": $tty, "last_assistant_message": $msg }'
  )" 2>/dev/null || true

exit 0
