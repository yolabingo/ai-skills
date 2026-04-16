#!/usr/bin/env bash
# PreToolUse hook: if a WebFetch targets a supported Git host URL that is already
# cached locally, surface the local path as a note. Does NOT block.
# Supports: github.com, gitlab.com, bitbucket.org, codeberg.org
set -euo pipefail

CACHE_BASE="${CACHE_BASE:-/var/tmp/yolabingo-ai-skills-gh-intercept-repo-dir}"
SUPPORTED_HOSTS="github\.com|gitlab\.com|bitbucket\.org|codeberg\.org"

INPUT=$(cat)
URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty' 2>/dev/null)

[[ -z "$URL" ]] && exit 0
echo "$URL" | grep -qE "(${SUPPORTED_HOSTS}|raw\.githubusercontent\.com)" || exit 0

# Parse owner/repo/file from URL
HOST="" OWNER="" REPO="" FILE_PATH=""

if [[ "$URL" =~ raw\.githubusercontent\.com/([^/?#]+)/([^/?#]+)/([^/?#]+)/(.+) ]]; then
    HOST="github.com"
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"; FILE_PATH="${BASH_REMATCH[4]}"
elif [[ "$URL" =~ ($SUPPORTED_HOSTS)/([^/?#]+)/([^/?#]+)(/-)*/blob/([^/?#]+)/(.+) ]]; then
    HOST="${BASH_REMATCH[1]}"
    OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"; FILE_PATH="${BASH_REMATCH[6]}"
elif [[ "$URL" =~ (bitbucket\.org)/([^/?#]+)/([^/?#]+)/src/([^/?#]+)/(.+) ]]; then
    HOST="${BASH_REMATCH[1]}"
    OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"; FILE_PATH="${BASH_REMATCH[5]}"
elif [[ "$URL" =~ ($SUPPORTED_HOSTS)/([^/?#]+)/([^/?#.]+) ]]; then
    HOST="${BASH_REMATCH[1]}"
    OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"
fi

[[ -z "$OWNER" || -z "$REPO" ]] && exit 0

SHORT_HOST="${HOST%%.*}"
SLUG="${SHORT_HOST}__${OWNER}__${REPO}"
REPO_DIR="$(find "$CACHE_BASE" -maxdepth 2 -type d -name "$SLUG" 2>/dev/null \
    | sort -r | head -1)"

# Only surface a note if clone is complete
[[ -z "$REPO_DIR" || -f "${REPO_DIR}.cloning" ]] && exit 0

if [[ -n "$FILE_PATH" && -f "${REPO_DIR}/${FILE_PATH}" ]]; then
    LOCAL_PATH="${REPO_DIR}/${FILE_PATH}"
    NOTE="[gh-intercept] ${HOST}/${OWNER}/${REPO} is cached locally. File available at: ${LOCAL_PATH} — consider using Read instead of WebFetch."
else
    NOTE="[gh-intercept] ${HOST}/${OWNER}/${REPO} is cached locally at: ${REPO_DIR} — consider using Grep/Read instead of WebFetch."
fi

jq -n --arg note "$NOTE" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": $note
  }
}'
