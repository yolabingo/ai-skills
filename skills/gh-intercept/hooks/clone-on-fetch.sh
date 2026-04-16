#!/usr/bin/env bash
# PostToolUse hook: when WebFetch hits a GitHub URL, kick off a background clone.
# Does NOT block or modify the fetch — purely a side effect.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_SCRIPT="${SCRIPT_DIR}/../scripts/gh-cache.sh"

INPUT=$(cat)
URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty' 2>/dev/null)

[[ -z "$URL" ]] && exit 0
echo "$URL" | grep -qE '(github\.com|raw\.githubusercontent\.com)' || exit 0

# Fire background clone — gh-cache.sh --background exits immediately
bash "$CACHE_SCRIPT" --background "$URL" 2>/dev/null || true
