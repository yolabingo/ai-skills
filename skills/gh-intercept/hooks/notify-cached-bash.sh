#!/usr/bin/env bash
# PreToolUse hook for Bash: if a gh/curl/wget/git-clone command targets a cached repo,
# BLOCK the command and direct Claude to use local Read/Grep instead.
# Supports: gh api, gh repo view, gh release/run download -R, curl, wget, git clone
set -euo pipefail

GH_INTERCEPT_CACHE_DIR="${GH_INTERCEPT_CACHE_DIR:-/var/tmp/yolabingo-ai-skills-gh-intercept-repo-dir}"
SUPPORTED_HOSTS="github\.com|gitlab\.com|bitbucket\.org|codeberg\.org"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[[ -z "$COMMAND" ]] && exit 0

OWNER="" REPO="" FILE_PATH="" HOST="" URL="" SEARCH_PATTERN=""

if [[ "$COMMAND" =~ gh[[:space:]]+api[[:space:]]+repos/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/contents/(.+) ]]; then
    HOST="github.com"
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"; FILE_PATH="${BASH_REMATCH[3]}"
    FILE_PATH="${FILE_PATH%%\?*}"; FILE_PATH="${FILE_PATH%% *}"
elif [[ "$COMMAND" =~ gh[[:space:]]+api[[:space:]]+repos/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    HOST="github.com"
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
elif [[ "$COMMAND" =~ gh[[:space:]]+repo[[:space:]]+view[[:space:]]+([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    HOST="github.com"
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
elif [[ "$COMMAND" =~ gh[[:space:]]+search[[:space:]]+code[[:space:]] ]]; then
    HOST="github.com"
    if [[ "$COMMAND" =~ (--repo|-R)[[:space:]]+([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
        OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"
    fi
    if [[ "$COMMAND" =~ gh[[:space:]]+search[[:space:]]+code[[:space:]]+[\"\']([^\"\']+)[\"\'] ]]; then
        SEARCH_PATTERN="${BASH_REMATCH[1]}"
    elif [[ "$COMMAND" =~ gh[[:space:]]+search[[:space:]]+code[[:space:]]+([^[:space:]-][^[:space:]]*) ]]; then
        SEARCH_PATTERN="${BASH_REMATCH[1]}"
    fi
elif [[ "$COMMAND" =~ gh[[:space:]]+(release|run)[[:space:]]+download.*-R[[:space:]]+([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]]; then
    HOST="github.com"
    OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"
else
    # curl, wget, git clone — extract first git-host URL from command
    if [[ "$COMMAND" =~ (https?://raw\.githubusercontent\.com/[^[:space:]]+) ]]; then
        URL="${BASH_REMATCH[1]}"
    elif [[ "$COMMAND" =~ (https?://(api\.github\.com|github\.com|gitlab\.com|bitbucket\.org|codeberg\.org)/[^[:space:]]+) ]]; then
        URL="${BASH_REMATCH[1]}"
    fi

    [[ -z "$URL" ]] && exit 0

    # Parse owner/repo/file from URL (api.github.com must come before generic github.com)
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
    elif [[ "$URL" =~ ($SUPPORTED_HOSTS)/([^/?#]+)/([^/?#.]+) ]]; then
        HOST="${BASH_REMATCH[1]}"
        OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"
    fi
fi

[[ -z "$OWNER" || -z "$REPO" ]] && exit 0

SHORT_HOST="${HOST%%.*}"
SLUG="${SHORT_HOST}__${OWNER}__${REPO}"
REPO_DIR="$(find "$GH_INTERCEPT_CACHE_DIR" -maxdepth 2 -type d -name "$SLUG" 2>/dev/null \
    | sort -r | head -1)"

[[ -z "$REPO_DIR" || -f "${REPO_DIR}.cloning" ]] && exit 0

if [[ -n "$SEARCH_PATTERN" ]]; then
    REASON="[gh-intercept] BLOCKED: ${HOST}/${OWNER}/${REPO} is cached locally. Use Grep tool to search for \"${SEARCH_PATTERN}\" in: ${REPO_DIR}"
elif [[ -n "$FILE_PATH" && -f "${REPO_DIR}/${FILE_PATH}" ]]; then
    LOCAL_PATH="${REPO_DIR}/${FILE_PATH}"
    REASON="[gh-intercept] REDIRECT: ${HOST}/${OWNER}/${REPO} is cloned locally. Read this file instead: ${LOCAL_PATH} — Do NOT use browser, WebFetch, curl, or any other remote method to access files in this repo. Using gh to query gh api about repo metadata is fine."
else
    REASON="[gh-intercept] REDIRECT: ${HOST}/${OWNER}/${REPO} is cloned locally at: ${REPO_DIR} — Use Read/Grep/Glob on the local clone. Do NOT use browser, WebFetch, curl, or any other remote method to access files in this repo. Using gh to query gh api about repo metadata is fine."
fi

jq -n --arg reason "$REASON" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $reason
  }
}'
