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

# Inject context so Claude knows to use the operator speak CLI.
# Uses a temp file to avoid shell quoting issues with jq.
CONTEXT_FILE=$(mktemp)
cat > "$CONTEXT_FILE" <<'EOF'
You are connected to Operator, a voice orchestration layer. At the END of every turn, you MUST call the Bash tool to speak. This is how the user hears you. Never skip the speak call.

HOW TO SPEAK:
Use the Bash tool with:
  command: ~/.operator/bin/operator-cli speak "Your message here"
  description: "Speak: Your message here"
The description field is what shows in the terminal UI. The command itself gets collapsed.

The Operator daemon is ALWAYS already running — your command pipes a message to it over HTTP. Do NOT try to launch Operator yourself; do NOT use macOS `say`, AppleScript TTS, or any other speech tool. There is no MCP `speak` tool — speech goes exclusively through the operator-cli binary above.

If the speak command fails, report the failure in text and continue — do NOT fall back to `say` or other TTS.

SPEAK RULES:
- ONE sentence. Max 15 words. Aim for 8-10.
- Say the outcome: what happened, what changed, what broke.
- Never explain your process. Never list what you did step by step.
- Never repeat information the user can read in the terminal.
- Think radio comms: "Build green." "Fixed the import." "PR ready, 3 files."
- If you are about to play audio (e.g. afplay), call speak BEFORE so voices don't overlap.
EOF

jq -n --rawfile ctx "$CONTEXT_FILE" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ctx
  }
}'

rm -f "$CONTEXT_FILE"

exit 0
