#!/usr/bin/env bash
# PreToolUse hook: if a WebFetch targets a GitHub URL that is already cached locally,
# surface the local path as a note. Does NOT block — the fetch proceeds normally.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_BASE="/var/tmp/claude/gh-repo-cache"

INPUT=$(cat)
URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty' 2>/dev/null)

[[ -z "$URL" ]] && exit 0
echo "$URL" | grep -qE '(github\.com|raw\.githubusercontent\.com)' || exit 0

# Parse owner/repo from URL (inline — no external call needed here)
OWNER="" REPO="" FILE_PATH=""

if [[ "$URL" =~ raw\.githubusercontent\.com/([^/?#]+)/([^/?#]+)/([^/?#]+)/(.+) ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"; FILE_PATH="${BASH_REMATCH[4]}"
elif [[ "$URL" =~ github\.com/([^/?#]+)/([^/?#]+)/blob/([^/?#]+)/(.+) ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"; FILE_PATH="${BASH_REMATCH[4]}"
elif [[ "$URL" =~ github\.com/([^/?#]+)/([^/?#.]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
fi

[[ -z "$OWNER" || -z "$REPO" ]] && exit 0

SLUG="${OWNER}__${REPO}"
REPO_DIR="$(find "$CACHE_BASE" -maxdepth 2 -type d -name "$SLUG" 2>/dev/null \
    | sort -r | head -1)"

# Only surface a note if clone is complete
[[ -z "$REPO_DIR" || -f "${REPO_DIR}.cloning" ]] && exit 0

if [[ -n "$FILE_PATH" && -f "${REPO_DIR}/${FILE_PATH}" ]]; then
    LOCAL_PATH="${REPO_DIR}/${FILE_PATH}"
    NOTE="[gh-intercept] ${OWNER}/${REPO} is cached locally. File available at: ${LOCAL_PATH} — consider using Read instead of WebFetch."
else
    NOTE="[gh-intercept] ${OWNER}/${REPO} is cached locally at: ${REPO_DIR} — consider using Grep/Read instead of WebFetch."
fi

# Allow the fetch through but annotate with local availability
jq -n --arg note "$NOTE" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": $note
  }
}'
