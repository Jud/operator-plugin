#!/bin/bash
set -euo pipefail

# Operator SessionStart hook
# Registers this Claude Code session with the Operator daemon and injects
# a system message instructing Claude to call the operator speak CLI.

source "$(dirname "$0")/_common.sh"
[[ -z "$TOKEN" ]] && exit 0

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // ""')

# POST registration to Operator daemon (best-effort)
curl -s -o /dev/null -w "" \
  -X POST "http://127.0.0.1:7420/hook/session-start" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg sid "$SESSION_NAME" \
    --arg tty "$TTY" \
    --arg cwd "$CWD" \
    '{ "session_id": $sid, "tty": $tty, "cwd": $cwd }'
  )" 2>/dev/null || true

# Add ~/.operator/bin to PATH for this Claude Code session
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo 'export PATH="$HOME/.operator/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
fi

# Inject context so Claude knows to use the operator speak CLI
jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "You are connected to Operator, a voice orchestration layer. At the END of every turn, you MUST call the `speak` MCP tool with a brief (1-2 sentence) spoken summary of what you did or your response. This is how the user hears you. Never skip the speak call.\n\nSPEAKING VIA BASH:\n`speak` is on your PATH. Just call it directly:\n  speak \"Your message here\"\n\nWHEN TO SPEAK:\n- ALWAYS at the end of every turn (so the user hears your response)\n- Before asking the user a question (so they hear you need them)\n- After completing substantial work (multi-file change, test run, build)\n- Before starting long-running work (so they know what is happening)\n\nWHEN NOT TO SPEAK:\n- Never skip speaking. The user relies on voice output.\n\nSPEAK RULES:\n- 1-2 sentences max. Status or outcome only.\n- Good: \"Build passed, PR ready.\" / \"Question — which auth strategy?\" / \"Starting test suite.\"\n- Bad: \"I have finished refactoring the auth module and all tests pass and everything looks good.\"\n\nPriority: --priority urgent (jumps queue), normal (default), low (background updates).\n\nIMPORTANT: If you are about to play audio (e.g. afplay), speak BEFORE the audio command so voices do not overlap."
  }
}'

exit 0
