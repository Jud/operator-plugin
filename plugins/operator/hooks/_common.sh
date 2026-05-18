#!/bin/bash
# Shared preamble for Operator Claude Code hooks.
# Source this at the top of each hook script to get:
#   HOOK_INPUT  — raw JSON from Claude Code
#   SESSION_ID  — .session_id from the hook payload
#   TTY         — TTY device path of the parent shell
#   TOKEN       — bearer token (empty-string if file missing)

HOOK_INPUT=$(cat)

SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')

# Derive a human-readable session name from CWD basename.
# Claude Code's session_id is an internal UUID — not useful as a display name.
# Prefer cwd from the hook payload, fall back to $PWD, then to the raw UUID.
_HOOK_CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // ""')
if [[ -n "$_HOOK_CWD" ]]; then
  SESSION_NAME=$(basename "$_HOOK_CWD")
elif [[ -n "$PWD" ]]; then
  SESSION_NAME=$(basename "$PWD")
else
  SESSION_NAME="$SESSION_ID"
fi

# Detect TTY of the parent shell (Claude Code's terminal)
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
if [[ -f "$TOKEN_FILE" ]]; then
  TOKEN=$(cat "$TOKEN_FILE")
else
  TOKEN=""
fi
