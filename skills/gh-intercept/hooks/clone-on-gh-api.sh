#!/usr/bin/env bash
# PostToolUse hook for Bash: when a gh api/repo command targets a GitHub repo,
# kick off a background clone. Does NOT block or modify the command.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_SCRIPT="${SCRIPT_DIR}/../scripts/gh-cache.sh"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[[ -z "$COMMAND" ]] && exit 0

OWNER="" REPO=""

if [[ "$COMMAND" =~ gh[[:space:]]+api[[:space:]]+repos/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
elif [[ "$COMMAND" =~ gh[[:space:]]+repo[[:space:]]+view[[:space:]]+([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
else
    exit 0
fi

[[ -z "$OWNER" || -z "$REPO" ]] && exit 0

# Fire background clone
bash "$CACHE_SCRIPT" --background "${OWNER}/${REPO}" 2>/dev/null || true
