#!/usr/bin/env bash
# PreToolUse hook for Bash: if a gh api/repo command targets a cached repo,
# surface the local path. Does NOT block — command proceeds normally.
set -euo pipefail

CACHE_BASE="${CACHE_BASE:-/var/tmp/claude/gh-repo-cache}"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[[ -z "$COMMAND" ]] && exit 0

# Match gh api repos/OWNER/REPO/contents/... or gh api repos/OWNER/REPO/git/trees/...
OWNER="" REPO="" FILE_PATH=""

if [[ "$COMMAND" =~ gh[[:space:]]+api[[:space:]]+repos/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/contents/(.+) ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"; FILE_PATH="${BASH_REMATCH[3]}"
    # Strip query params from file path
    FILE_PATH="${FILE_PATH%%\?*}"
    FILE_PATH="${FILE_PATH%% *}"
elif [[ "$COMMAND" =~ gh[[:space:]]+api[[:space:]]+repos/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/git/trees ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
elif [[ "$COMMAND" =~ gh[[:space:]]+api[[:space:]]+repos/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
elif [[ "$COMMAND" =~ gh[[:space:]]+repo[[:space:]]+view[[:space:]]+([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
else
    exit 0
fi

[[ -z "$OWNER" || -z "$REPO" ]] && exit 0

SLUG="github__${OWNER}__${REPO}"
REPO_DIR="$(find "$CACHE_BASE" -maxdepth 2 -type d -name "$SLUG" 2>/dev/null \
    | sort -r | head -1)"

# Only surface note if clone is complete
[[ -z "$REPO_DIR" || -f "${REPO_DIR}.cloning" ]] && exit 0

if [[ -n "$FILE_PATH" && -f "${REPO_DIR}/${FILE_PATH}" ]]; then
    LOCAL_PATH="${REPO_DIR}/${FILE_PATH}"
    NOTE="[gh-intercept] ${OWNER}/${REPO} is cached locally. File available at: ${LOCAL_PATH} — use Read instead of gh api."
else
    NOTE="[gh-intercept] ${OWNER}/${REPO} is cached locally at: ${REPO_DIR} — use Grep/Read/Glob on local clone instead of gh api."
fi

jq -n --arg note "$NOTE" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": $note
  }
}'
