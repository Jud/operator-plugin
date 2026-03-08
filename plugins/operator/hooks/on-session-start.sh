#!/bin/bash
set -euo pipefail

# Operator SessionStart hook
# Registers this Claude Code session with the Operator daemon and injects
# a system message instructing Claude to call the speak MCP tool.

HOOK_INPUT=$(cat)

SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // ""')

# Detect TTY of the parent shell (Claude Code's terminal)
TTY=$(ps -o tty= -p $PPID 2>/dev/null | tr -d '[:space:]') || true
if [[ -z "$TTY" ]]; then
  TTY="unknown"
else
  # Normalize to /dev/ path if not already
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

# POST registration to Operator daemon (best-effort)
curl -s -o /dev/null -w "" \
  -X POST "http://127.0.0.1:7420/hook/session-start" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg sid "$SESSION_ID" \
    --arg tty "$TTY" \
    --arg cwd "$CWD" \
    '{ "session_id": $sid, "tty": $tty, "cwd": $cwd }'
  )" 2>/dev/null || true

# Inject context so Claude knows to use the speak tool
jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "You are connected to Operator, a voice orchestration layer. At the END of every turn, you MUST call the `speak` MCP tool with a brief (1-2 sentence) spoken summary of what you did or your response. This is how the user hears you. Never skip the speak call."
  }
}'

exit 0
