#!/usr/bin/env bash
# PreToolUse hook: if a WebFetch targets a supported Git host URL that is already
# cached locally, BLOCK the fetch and direct Claude to use local Read/Grep instead.
# Supports: github.com, gitlab.com, bitbucket.org, codeberg.org
set -euo pipefail

GH_INTERCEPT_CACHE_DIR="${GH_INTERCEPT_CACHE_DIR:-/var/tmp/yolabingo-ai-skills-gh-intercept-repo-dir}"
SUPPORTED_HOSTS="github\.com|gitlab\.com|bitbucket\.org|codeberg\.org"

INPUT=$(cat)
URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty' 2>/dev/null)

[[ -z "$URL" ]] && exit 0
echo "$URL" | grep -qE "(api\.github\.com|${SUPPORTED_HOSTS}|raw\.githubusercontent\.com)" || exit 0

# Parse owner/repo/file from URL
HOST="" OWNER="" REPO="" FILE_PATH=""

if [[ "$URL" =~ api\.github\.com/repos/([^/?#]+)/([^/?#]+) ]]; then
    HOST="github.com"
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
    if [[ "$URL" =~ /contents/([^?#]+) ]]; then
        FILE_PATH="${BASH_REMATCH[1]}"
    fi
elif [[ "$URL" =~ raw\.githubusercontent\.com/([^/?#]+)/([^/?#]+)/([^/?#]+)/(.+) ]]; then
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
REPO_DIR="$(find "$GH_INTERCEPT_CACHE_DIR" -maxdepth 2 -type d -name "$SLUG" 2>/dev/null \
    | sort -r | head -1)"

# Only surface a note if clone is complete
[[ -z "$REPO_DIR" || -f "${REPO_DIR}.cloning" ]] && exit 0

if [[ -n "$FILE_PATH" && -f "${REPO_DIR}/${FILE_PATH}" ]]; then
    LOCAL_PATH="${REPO_DIR}/${FILE_PATH}"
    REASON="[gh-intercept] BLOCKED: ${HOST}/${OWNER}/${REPO} is cached locally. Use Read tool on: ${LOCAL_PATH}"
else
    REASON="[gh-intercept] BLOCKED: ${HOST}/${OWNER}/${REPO} is cached locally at: ${REPO_DIR} — use Read/Grep/Glob on local clone instead of WebFetch."
fi

jq -n --arg reason "$REASON" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $reason
  }
}'
