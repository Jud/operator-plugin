#!/bin/bash
set -euo pipefail

# Operator SessionStart hook
# Registers this Claude Code session with the Operator daemon and injects
# a system message instructing Claude to call the operator speak CLI.
#
# Headless runs (claude -p / --print) skip registration so they get no
# connected/disconnected announcements; speaking becomes optional for them.

source "$(dirname "$0")/_common.sh"
[[ -z "$TOKEN" ]] && exit 0

CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // ""')

# POST registration to Operator daemon (best-effort, fire-and-forget —
# backgrounded with all fds redirected so the hook never waits on the HTTP
# round trip).
if [[ "$HEADLESS" != "true" ]]; then
  curl -s -m 5 -o /dev/null \
    -X POST "http://127.0.0.1:7420/hook/session-start" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg sid "$SESSION_NAME" \
      --arg tty "$TTY" \
      --arg cwd "$CWD" \
      '{ "session_id": $sid, "tty": $tty, "cwd": $cwd }'
    )" >/dev/null 2>&1 &
fi

# Add ~/.operator/bin to PATH for this Claude Code session
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo 'export PATH="$HOME/.operator/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
fi

# Inject context so Claude knows to use the operator speak CLI.
# Uses a temp file to avoid shell quoting issues with jq.
CONTEXT_FILE=$(mktemp)
if [[ "$HEADLESS" == "true" ]]; then
cat > "$CONTEXT_FILE" <<'EOF'
Operator, a voice orchestration layer, is available in this session. This is a non-interactive (headless) run, so speaking is OPTIONAL: never announce progress, and do not speak routine or trivial results.

If the run produced an outcome worth saying out loud, you MAY end with ONE short spoken summary via the Bash tool:
  command: ~/.operator/bin/operator-cli speak "Your message here"
  description: "Speak: Your message here"

Keep it to one sentence, max 15 words, outcome only. Never use macOS `say`, AppleScript TTS, or any other speech tool. If the speak command fails, ignore it and continue.
EOF
else
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
fi

jq -n --rawfile ctx "$CONTEXT_FILE" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ctx
  }
}'

rm -f "$CONTEXT_FILE"

exit 0
