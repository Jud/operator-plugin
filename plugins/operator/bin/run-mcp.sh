#!/bin/bash
export OPERATOR_TOKEN=$(cat "$HOME/.operator/token" 2>/dev/null)
export OPERATOR_PORT="${OPERATOR_PORT:-7420}"
exec "$HOME/.operator/bin/operator-mcp" "$@"
