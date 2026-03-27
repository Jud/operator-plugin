#!/bin/bash
set -euo pipefail

# Operator SessionStart hook
# Registers this Claude Code session with the Operator daemon and injects
# a system message instructing Claude to call the operator speak CLI.

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

# Inject context so Claude knows to use the operator speak CLI
jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "You are connected to Operator, a voice orchestration layer. Speak to the user by running `~/.operator/bin/operator-cli speak \"<message>\"` via the Bash tool. One sentence max — like a walkie-talkie, not a presentation.\n\nWHEN TO SPEAK:\n- ALWAYS before asking the user a question (so they hear you need them)\n- After completing substantial work (multi-file change, test run, build)\n- Before starting long-running work (so they know what is happening)\n\nWHEN NOT TO SPEAK:\n- Short responses (1-2 lines) the user will read faster than you can say them\n- Simple acknowledgments like \"Done.\" or \"Got it.\" — the text is enough\n- Do not repeat what is already visible in your text output\n\nHOW TO SPEAK:\n- 5-10 words. Status or outcome only.\n- Good: \"Build passed, PR ready.\" / \"Question — which auth strategy?\" / \"Starting test suite.\"\n- Bad: \"I have finished refactoring the auth module and all tests pass.\"\n\nPriority: --priority urgent (jumps queue), normal (default), low (background updates).\n\nIMPORTANT: If you are about to play audio (e.g. afplay), speak BEFORE the audio command so voices do not overlap."
  }
}'

exit 0
