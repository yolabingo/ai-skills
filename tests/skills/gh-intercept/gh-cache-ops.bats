#!/usr/bin/env bats
# Tests for gh-cache.sh cache operations (find, evict, prune, list).
# Uses a temp directory instead of the real cache.
# Requires: bats-core (brew install bats-core)

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
GH_CACHE="${SCRIPT_DIR}/../../../skills/gh-intercept/scripts/gh-cache.sh"

setup() {
    TEST_CACHE="$(mktemp -d)"
    export GH_INTERCEPT_CACHE_DIR="$TEST_CACHE"
    export TODAY="2026-04-15"
    export TODAY_DIR="${GH_INTERCEPT_CACHE_DIR}/${TODAY}"

    GH_CACHE_SOURCED=1 source "$GH_CACHE"
    # Override globals set during source
    GH_INTERCEPT_CACHE_DIR="$TEST_CACHE"
    TODAY_DIR="${GH_INTERCEPT_CACHE_DIR}/${TODAY}"
}

teardown() {
    rm -rf "$TEST_CACHE"
}

# ── find_cached ──────────────────────────────────────────────────────────────

@test "find_cached: returns path when repo exists" {
    mkdir -p "${TEST_CACHE}/2026-04-15/github__dotcms__core"
    result="$(find_cached "github__dotcms__core")"
    [[ "$result" == "${TEST_CACHE}/2026-04-15/github__dotcms__core" ]]
}

@test "find_cached: returns empty when not cached" {
    mkdir -p "${TEST_CACHE}/2026-04-15"
    result="$(find_cached "github__nonexistent__repo")"
    [[ -z "$result" ]]
}

@test "find_cached: ignores repos with .cloning sentinel" {
    mkdir -p "${TEST_CACHE}/2026-04-15/github__dotcms__core"
    touch "${TEST_CACHE}/2026-04-15/github__dotcms__core.cloning"
    result="$(find_cached "github__dotcms__core")"
    [[ -z "$result" ]]
}

@test "find_cached: returns newest date when multiple exist" {
    mkdir -p "${TEST_CACHE}/2026-04-10/github__owner__repo"
    mkdir -p "${TEST_CACHE}/2026-04-15/github__owner__repo"
    result="$(find_cached "github__owner__repo")"
    [[ "$result" == "${TEST_CACHE}/2026-04-15/github__owner__repo" ]]
}

# ── is_cloning ───────────────────────────────────────────────────────────────

@test "is_cloning: returns sentinel path when cloning" {
    mkdir -p "${TEST_CACHE}/2026-04-15"
    touch "${TEST_CACHE}/2026-04-15/github__owner__repo.cloning"
    result="$(is_cloning "github__owner__repo")"
    [[ -n "$result" ]]
}

@test "is_cloning: returns empty when not cloning" {
    mkdir -p "${TEST_CACHE}/2026-04-15"
    result="$(is_cloning "github__owner__repo")"
    [[ -z "$result" ]]
}

# ── prune_old ────────────────────────────────────────────────────────────────

@test "prune: removes dirs older than cutoff" {
    CUTOFF="2026-04-01"
    mkdir -p "${TEST_CACHE}/2026-03-15/github__old__repo"
    mkdir -p "${TEST_CACHE}/2026-04-15/github__new__repo"

    prune_old 2>/dev/null

    [[ ! -d "${TEST_CACHE}/2026-03-15" ]]
    [[ -d "${TEST_CACHE}/2026-04-15/github__new__repo" ]]
}

@test "prune: keeps dirs newer than cutoff" {
    CUTOFF="2026-03-01"
    mkdir -p "${TEST_CACHE}/2026-03-15/github__recent__repo"

    prune_old 2>/dev/null

    [[ -d "${TEST_CACHE}/2026-03-15/github__recent__repo" ]]
}

@test "prune: ignores non-date directories" {
    CUTOFF="2026-04-01"
    mkdir -p "${TEST_CACHE}/not-a-date/github__owner__repo"

    prune_old 2>/dev/null

    [[ -d "${TEST_CACHE}/not-a-date/github__owner__repo" ]]
}

# ── cmd_list ─────────────────────────────────────────────────────────────────

@test "list: shows cached repos" {
    mkdir -p "${TEST_CACHE}/2026-04-15/github__dotcms__core"
    mkdir -p "${TEST_CACHE}/2026-04-15/gitlab__org__project"

    result="$(cmd_list)"
    [[ "$result" == *"github/dotcms/core"* ]]
    [[ "$result" == *"gitlab/org/project"* ]]
}

@test "list: shows (cache empty) when nothing cached" {
    rm -rf "$TEST_CACHE"
    result="$(cmd_list)"
    [[ "$result" == "(cache empty)" ]]
}

# ── cmd_evict ────────────────────────────────────────────────────────────────

@test "evict: removes cached repo" {
    mkdir -p "${TEST_CACHE}/2026-04-15/github__dotcms__core"
    cmd_evict "dotcms/core" 2>/dev/null

    [[ ! -d "${TEST_CACHE}/2026-04-15/github__dotcms__core" ]]
}

@test "evict: reports not cached for missing repo" {
    result="$(cmd_evict "nonexistent/repo" 2>&1)" || true
    [[ "$result" == *"Not cached"* ]]
}
