#!/usr/bin/env bash
# PreToolUse hook: if a WebSearch query references a cached GitHub/GitLab/etc repo,
# BLOCK the search and direct Claude to use local Read/Grep instead.
set -euo pipefail

GH_INTERCEPT_CACHE_DIR="${GH_INTERCEPT_CACHE_DIR:-/var/tmp/yolabingo-ai-skills-gh-intercept-repo-dir}"
SUPPORTED_HOSTS="github\.com|gitlab\.com|bitbucket\.org|codeberg\.org"

INPUT=$(cat)
QUERY=$(echo "$INPUT" | jq -r '.tool_input.query // empty' 2>/dev/null)

[[ -z "$QUERY" ]] && exit 0

# Only act when query mentions a supported host
echo "$QUERY" | grep -qiE "(api\.github\.com|github\.com|gitlab\.com|bitbucket\.org|codeberg\.org)" || exit 0

OWNER="" REPO="" HOST=""

# Extract host/owner/repo from query
if [[ "$QUERY" =~ api\.github\.com/repos/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    HOST="github.com"
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
elif [[ "$QUERY" =~ (github\.com|gitlab\.com|bitbucket\.org|codeberg\.org)/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    HOST="${BASH_REMATCH[1]}"
    OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"
fi

[[ -z "$OWNER" || -z "$REPO" ]] && exit 0

SHORT_HOST="${HOST%%.*}"
SLUG="${SHORT_HOST}__${OWNER}__${REPO}"
REPO_DIR="$(find "$GH_INTERCEPT_CACHE_DIR" -maxdepth 2 -type d -name "$SLUG" 2>/dev/null \
    | sort -r | head -1)"

[[ -z "$REPO_DIR" || -f "${REPO_DIR}.cloning" ]] && exit 0

REASON="[gh-intercept] BLOCKED: ${HOST}/${OWNER}/${REPO} is cached locally at: ${REPO_DIR} — use Read/Grep/Glob on local clone instead of WebSearch."

jq -n --arg reason "$REASON" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $reason
  }
}'
