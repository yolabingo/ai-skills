#!/usr/bin/env bash
# PostToolUse hook for Bash: when a gh/curl/wget/git-clone command targets a repo,
# kick off a background clone. Does NOT block or modify the command.
# Supports: gh api, gh repo view, gh release/run download -R, curl, wget, git clone
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_SCRIPT="${SCRIPT_DIR}/../scripts/gh-cache.sh"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[[ -z "$COMMAND" ]] && exit 0

CACHE_REF=""

if [[ "$COMMAND" =~ gh[[:space:]]+api[[:space:]]+repos/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    CACHE_REF="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
elif [[ "$COMMAND" =~ gh[[:space:]]+repo[[:space:]]+view[[:space:]]+([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    CACHE_REF="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
elif [[ "$COMMAND" =~ gh[[:space:]]+(release|run)[[:space:]]+download.*-R[[:space:]]+([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    CACHE_REF="${BASH_REMATCH[2]}/${BASH_REMATCH[3]}"
else
    # curl, wget, git clone — extract first git-host URL from command
    if [[ "$COMMAND" =~ (https?://raw\.githubusercontent\.com/[^[:space:]]+) ]]; then
        CACHE_REF="${BASH_REMATCH[1]}"
    elif [[ "$COMMAND" =~ (https?://(api\.github\.com|github\.com|gitlab\.com|bitbucket\.org|codeberg\.org)/[^[:space:]]+) ]]; then
        CACHE_REF="${BASH_REMATCH[1]}"
    fi
fi

[[ -z "$CACHE_REF" ]] && exit 0

bash "$CACHE_SCRIPT" --background "$CACHE_REF" 2>/dev/null || true
