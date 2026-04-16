#!/usr/bin/env bats
# Tests for gh-intercept hook scripts.
# Verifies URL matching and JSON output format.
# Requires: bats-core, jq

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
HOOKS_DIR="${SCRIPT_DIR}/../../../skills/gh-intercept/hooks"

setup() {
    TEST_CACHE="$(mktemp -d)"
    # Patch GH_INTERCEPT_CACHE_DIR in hook scripts via env (hooks read it directly)
    export GH_INTERCEPT_CACHE_DIR="$TEST_CACHE"
}

teardown() {
    rm -rf "$TEST_CACHE"
}

# Helper: simulate hook stdin with WebFetch tool_input
webfetch_input() {
    echo "{\"tool_input\":{\"url\":\"$1\"}}"
}

# Helper: simulate hook stdin with Bash tool_input
bash_input() {
    echo "{\"tool_input\":{\"command\":\"$1\"}}"
}

# ── notify-cached.sh (PreToolUse WebFetch) ───────────────────────────────────

@test "notify-cached: exits silently for non-git URLs" {
    result="$(webfetch_input "https://example.com/page" | bash "$HOOKS_DIR/notify-cached.sh")"
    [[ -z "$result" ]]
}

@test "notify-cached: exits silently when repo not cached" {
    result="$(webfetch_input "https://github.com/owner/repo" | bash "$HOOKS_DIR/notify-cached.sh")"
    [[ -z "$result" ]]
}

@test "notify-cached: surfaces note when github repo cached" {
    mkdir -p "${TEST_CACHE}/2026-04-15/github__dotcms__core"
    result="$(webfetch_input "https://github.com/dotcms/core" | GH_INTERCEPT_CACHE_DIR="$TEST_CACHE" bash "$HOOKS_DIR/notify-cached.sh")"
    echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
    echo "$result" | jq -e '.hookSpecificOutput.permissionDecisionReason | contains("cached locally")'
}

@test "notify-cached: surfaces note for gitlab URL" {
    mkdir -p "${TEST_CACHE}/2026-04-15/gitlab__org__project"
    result="$(webfetch_input "https://gitlab.com/org/project" | GH_INTERCEPT_CACHE_DIR="$TEST_CACHE" bash "$HOOKS_DIR/notify-cached.sh")"
    echo "$result" | jq -e '.hookSpecificOutput.permissionDecisionReason | contains("gitlab.com")'
}

@test "notify-cached: surfaces note for bitbucket URL" {
    mkdir -p "${TEST_CACHE}/2026-04-15/bitbucket__team__lib"
    result="$(webfetch_input "https://bitbucket.org/team/lib" | GH_INTERCEPT_CACHE_DIR="$TEST_CACHE" bash "$HOOKS_DIR/notify-cached.sh")"
    echo "$result" | jq -e '.hookSpecificOutput.permissionDecisionReason | contains("bitbucket.org")'
}

@test "notify-cached: surfaces file path for blob URL" {
    mkdir -p "${TEST_CACHE}/2026-04-15/github__owner__repo"
    mkdir -p "${TEST_CACHE}/2026-04-15/github__owner__repo/src"
    echo "content" > "${TEST_CACHE}/2026-04-15/github__owner__repo/src/app.py"
    result="$(webfetch_input "https://github.com/owner/repo/blob/main/src/app.py" | GH_INTERCEPT_CACHE_DIR="$TEST_CACHE" bash "$HOOKS_DIR/notify-cached.sh")"
    echo "$result" | jq -e '.hookSpecificOutput.permissionDecisionReason | contains("src/app.py")'
}

@test "notify-cached: skips repo with .cloning sentinel" {
    mkdir -p "${TEST_CACHE}/2026-04-15/github__owner__repo"
    touch "${TEST_CACHE}/2026-04-15/github__owner__repo.cloning"
    result="$(webfetch_input "https://github.com/owner/repo" | GH_INTERCEPT_CACHE_DIR="$TEST_CACHE" bash "$HOOKS_DIR/notify-cached.sh")"
    [[ -z "$result" ]]
}

# ── clone-on-fetch.sh (PostToolUse WebFetch) ─────────────────────────────────

@test "clone-on-fetch: exits silently for non-git URLs" {
    result="$(webfetch_input "https://example.com/page" | bash "$HOOKS_DIR/clone-on-fetch.sh" 2>&1)"
    [[ -z "$result" ]]
}

@test "clone-on-fetch: matches github URL" {
    # Can't test actual clone, but verify it doesn't error on valid URL
    # (clone will fail silently due to 2>/dev/null || true)
    webfetch_input "https://github.com/owner/repo" | bash "$HOOKS_DIR/clone-on-fetch.sh" 2>/dev/null
}

@test "clone-on-fetch: matches gitlab URL" {
    webfetch_input "https://gitlab.com/org/project" | bash "$HOOKS_DIR/clone-on-fetch.sh" 2>/dev/null
}

@test "clone-on-fetch: matches bitbucket URL" {
    webfetch_input "https://bitbucket.org/team/lib" | bash "$HOOKS_DIR/clone-on-fetch.sh" 2>/dev/null
}

@test "clone-on-fetch: matches codeberg URL" {
    webfetch_input "https://codeberg.org/user/proj" | bash "$HOOKS_DIR/clone-on-fetch.sh" 2>/dev/null
}

# ── notify-cached-bash.sh (PreToolUse Bash) ──────────────────────────────────

@test "notify-cached-bash: exits silently for non-gh commands" {
    result="$(bash_input "ls -la" | bash "$HOOKS_DIR/notify-cached-bash.sh")"
    [[ -z "$result" ]]
}

@test "notify-cached-bash: surfaces note for gh api repos/owner/repo" {
    mkdir -p "${TEST_CACHE}/2026-04-15/github__dotcms__core"
    result="$(bash_input "gh api repos/dotcms/core/contents/README.md" | GH_INTERCEPT_CACHE_DIR="$TEST_CACHE" bash "$HOOKS_DIR/notify-cached-bash.sh")"
    echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
    echo "$result" | jq -e '.hookSpecificOutput.permissionDecisionReason | contains("cached locally")'
}

@test "notify-cached-bash: surfaces note for gh repo view" {
    mkdir -p "${TEST_CACHE}/2026-04-15/github__dotcms__core"
    result="$(bash_input "gh repo view dotcms/core" | GH_INTERCEPT_CACHE_DIR="$TEST_CACHE" bash "$HOOKS_DIR/notify-cached-bash.sh")"
    echo "$result" | jq -e '.hookSpecificOutput.permissionDecisionReason | contains("cached locally")'
}
