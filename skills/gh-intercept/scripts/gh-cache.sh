#!/usr/bin/env bash
# gh-cache.sh — GitHub repo cache manager
# Usage:
#   gh-cache.sh <url-or-owner/repo> [--branch <branch>]   → ensure cloned, print local path
#   gh-cache.sh --background <url-or-owner/repo>           → fire-and-forget clone
#   gh-cache.sh --list                                      → show cached repos
#   gh-cache.sh --evict <owner/repo>                       → remove from cache
#
# Stdout: resolved local path (file or repo root).
# Stderr: status messages only.
set -euo pipefail

CACHE_BASE="/var/tmp/claude/gh-repo-cache"
TODAY="$(date +%Y-%m-%d)"
TODAY_DIR="${CACHE_BASE}/${TODAY}"
CUTOFF="$(date -v-1m +%Y-%m-%d 2>/dev/null || date -d '1 month ago' +%Y-%m-%d)"

die() { echo "ERROR: $*" >&2; exit 1; }

# ── URL parser ────────────────────────────────────────────────────────────────
parse_github_ref() {
    local input="$1"
    OWNER="" REPO="" BRANCH="" FILE_PATH=""

    # raw.githubusercontent.com/owner/repo/branch/path
    if [[ "$input" =~ raw\.githubusercontent\.com/([^/?#]+)/([^/?#]+)/([^/?#]+)/(.+) ]]; then
        OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
        BRANCH="${BASH_REMATCH[3]}"; FILE_PATH="${BASH_REMATCH[4]}"
        return 0
    fi
    # github.com/owner/repo/blob/branch/path
    if [[ "$input" =~ github\.com/([^/?#]+)/([^/?#]+)/blob/([^/?#]+)/(.+) ]]; then
        OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
        BRANCH="${BASH_REMATCH[3]}"; FILE_PATH="${BASH_REMATCH[4]}"
        return 0
    fi
    # github.com/owner/repo/tree/branch[/subdir]
    if [[ "$input" =~ github\.com/([^/?#]+)/([^/?#]+)/tree/([^/?#]+)(/[^?#]*)? ]]; then
        OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
        BRANCH="${BASH_REMATCH[3]}"; FILE_PATH="${BASH_REMATCH[4]:-}"; FILE_PATH="${FILE_PATH#/}"
        return 0
    fi
    # github.com/owner/repo
    if [[ "$input" =~ github\.com/([^/?#]+)/([^/?#.]+)(\.git)?([/?#].*)?$ ]]; then
        OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
        return 0
    fi
    # owner/repo
    if [[ "$input" =~ ^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$ ]]; then
        OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
        return 0
    fi
    return 1
}

# ── cache helpers ─────────────────────────────────────────────────────────────

find_cached() {
    # Return path only if clone is complete (no .cloning sentinel sibling)
    local slug="$1" found
    found="$(find "$CACHE_BASE" -maxdepth 2 -type d -name "$slug" 2>/dev/null \
        | sort -r | head -1)" || true
    if [[ -n "$found" && ! -f "${found}.cloning" ]]; then
        echo "$found"
    fi
}

is_cloning() {
    local slug="$1"
    find "$CACHE_BASE" -maxdepth 2 -name "${slug}.cloning" -type f 2>/dev/null \
        | head -1 || true
}

prune_old() {
    local dir dir_date
    while IFS= read -r -d '' dir; do
        dir_date="$(basename "$dir")"
        if [[ "$dir_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$dir_date" < "$CUTOFF" ]]; then
            echo "[gh-cache] Pruning: $dir" >&2
            rm -rf "$dir"
        fi
    done < <(find "$CACHE_BASE" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
}

do_clone() {
    local slug="$1" clone_url="$2"; shift 2
    local clone_args=("$@")
    local target="${TODAY_DIR}/${slug}"
    local sentinel="${target}.cloning"

    mkdir -p "$TODAY_DIR"
    touch "$sentinel" 2>/dev/null || true

    if git clone "${clone_args[@]}" --quiet "$clone_url" "$target" 2>/tmp/gh-clone-err; then
        rm -f "$sentinel"
        echo "[gh-cache] Cloned: ${clone_url} → ${target}" >&2
    else
        rm -rf "$target" "$sentinel"
        echo "[gh-cache] Clone failed: ${clone_url}" >&2
        exit 1
    fi
}

# ── subcommands ───────────────────────────────────────────────────────────────

cmd_list() {
    [[ ! -d "$CACHE_BASE" ]] && echo "(cache empty)" && return
    echo "Cache: $CACHE_BASE"; echo ""
    while IFS= read -r -d '' date_dir; do
        local repos=()
        while IFS= read -r -d '' repo_dir; do
            local label
            label="$(basename "$repo_dir" | sed 's/__/\//g')"
            [[ -f "${repo_dir}/.cloning" ]] && label+=" (cloning...)"
            repos+=("$label")
        done < <(find "$date_dir" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
        [[ ${#repos[@]} -gt 0 ]] && echo "$(basename "$date_dir"):" && printf '  %s\n' "${repos[@]}"
    done < <(find "$CACHE_BASE" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null | sort -rz)
}

cmd_evict() {
    parse_github_ref "$1" || die "Cannot parse: $1"
    local slug="${OWNER}__${REPO}"
    local found
    found="$(find "$CACHE_BASE" -maxdepth 2 -type d -name "$slug" 2>/dev/null | head -1)"
    if [[ -n "$found" ]]; then
        rm -rf "$found"; rmdir "$(dirname "$found")" 2>/dev/null || true
        echo "Evicted: $found" >&2
    else
        echo "Not cached: $1" >&2
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────

case "${1:-}" in
    --list)    cmd_list; exit 0 ;;
    --evict)   [[ -z "${2:-}" ]] && die "Usage: --evict <owner/repo>"; cmd_evict "$2"; exit 0 ;;
    --background)
        # Fire-and-forget: parse, check, clone async, exit immediately
        [[ -z "${2:-}" ]] && die "Usage: --background <url-or-owner/repo>"
        parse_github_ref "$2" || exit 0  # non-GitHub URL — silently exit
        SLUG="${OWNER}__${REPO}"
        EXISTING="$(find_cached "$SLUG")" || true
        [[ -n "$EXISTING" ]] && exit 0  # already cached
        CLONING="$(is_cloning "$SLUG")" || true
        [[ -n "$CLONING" ]] && exit 0  # already in progress
        CLONE_URL="https://github.com/${OWNER}/${REPO}.git"
        CLONE_ARGS=(--depth 1 --filter=blob:limit=100k)
        [[ -n "$BRANCH" ]] && CLONE_ARGS+=(--branch "$BRANCH")
        mkdir -p "$TODAY_DIR"
        # Launch detached subprocess
        (do_clone "$SLUG" "$CLONE_URL" "${CLONE_ARGS[@]}" </dev/null &>/tmp/gh-clone-${SLUG}.log) &
        disown
        exit 0 ;;
    "")
        die "Usage: gh-cache.sh <url-or-owner/repo> [--branch <branch>]" ;;
esac

# Synchronous: ensure cloned and return path
INPUT="$1"
BRANCH_OVERRIDE=""
[[ "${2:-}" == "--branch" ]] && BRANCH_OVERRIDE="${3:-}"

parse_github_ref "$INPUT" || die "Cannot parse GitHub reference: $INPUT"
[[ -n "$BRANCH_OVERRIDE" ]] && BRANCH="$BRANCH_OVERRIDE"

SLUG="${OWNER}__${REPO}"
CLONE_URL="https://github.com/${OWNER}/${REPO}.git"
CLONE_ARGS=(--depth 1 --filter=blob:limit=100k)
[[ -n "$BRANCH" ]] && CLONE_ARGS+=(--branch "$BRANCH")

mkdir -p "$TODAY_DIR"
EXISTING="$(find_cached "$SLUG")" || true

if [[ -n "$EXISTING" ]]; then
    if [[ "$EXISTING" != "${TODAY_DIR}/${SLUG}" ]]; then
        echo "[gh-cache] Hit (moving to today): ${OWNER}/${REPO}" >&2
        mv "$EXISTING" "${TODAY_DIR}/${SLUG}"
        rmdir "$(dirname "$EXISTING")" 2>/dev/null || true
    else
        echo "[gh-cache] Hit: ${OWNER}/${REPO}" >&2
    fi
elif [[ -n "$(is_cloning "$SLUG")" ]]; then
    die "Clone in progress for ${OWNER}/${REPO} — try again shortly"
else
    echo "[gh-cache] Cloning ${OWNER}/${REPO}${BRANCH:+ @ ${BRANCH}} ..." >&2
    do_clone "$SLUG" "$CLONE_URL" "${CLONE_ARGS[@]}"
fi

REPO_DIR="${TODAY_DIR}/${SLUG}"
[[ -n "$FILE_PATH" ]] && echo "${REPO_DIR}/${FILE_PATH}" || echo "$REPO_DIR"

prune_old
