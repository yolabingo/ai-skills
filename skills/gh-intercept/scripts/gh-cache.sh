#!/usr/bin/env bash
# gh-cache.sh — Git repo cache manager (GitHub, GitLab, Bitbucket, Codeberg)
# Usage:
#   gh-cache.sh <url-or-owner/repo> [--branch <branch>]   → ensure cloned, print local path
#   gh-cache.sh --background <url-or-owner/repo>           → fire-and-forget clone
#   gh-cache.sh --list                                      → show cached repos
#   gh-cache.sh --evict <owner/repo>                       → remove from cache
#
# Supports: github.com, gitlab.com, bitbucket.org, codeberg.org
# For owner/repo shorthand (no host), defaults to github.com.
#
# Stdout: resolved local path (file or repo root).
# Stderr: status messages only.
set -euo pipefail

GH_INTERCEPT_CACHE_DIR="/var/tmp/yolabingo-ai-skills-gh-intercept-repo-dir"
TODAY="$(date +%Y-%m-%d)"
TODAY_DIR="${GH_INTERCEPT_CACHE_DIR}/${TODAY}"

# Configurable via environment variables
CLAUDE_PLUGIN_RETENTION_DAYS="${CLAUDE_PLUGIN_RETENTION_DAYS:-30}"
CLAUDE_PLUGIN_MAX_FILE_SIZE="${CLAUDE_PLUGIN_MAX_FILE_SIZE:-200k}"

CUTOFF="$(date -v-${CLAUDE_PLUGIN_RETENTION_DAYS}d +%Y-%m-%d 2>/dev/null || date -d "${CLAUDE_PLUGIN_RETENTION_DAYS} days ago" +%Y-%m-%d)"

die() { echo "ERROR: $*" >&2; exit 1; }

# Supported platforms
SUPPORTED_HOSTS="github\.com|gitlab\.com|bitbucket\.org|codeberg\.org"

# ── URL parser ────────────────────────────────────────────────────────────────
parse_repo_ref() {
    local input="$1"
    HOST="" OWNER="" REPO="" BRANCH="" FILE_PATH=""

    # raw.githubusercontent.com/owner/repo/branch/path (GitHub-specific)
    if [[ "$input" =~ raw\.githubusercontent\.com/([^/?#]+)/([^/?#]+)/([^/?#]+)/(.+) ]]; then
        HOST="github.com"
        OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
        BRANCH="${BASH_REMATCH[3]}"; FILE_PATH="${BASH_REMATCH[4]}"
        return 0
    fi
    # {host}/owner/repo/blob/branch/path (GitHub) or {host}/owner/repo/-/blob/branch/path (GitLab)
    if [[ "$input" =~ ($SUPPORTED_HOSTS)/([^/?#]+)/([^/?#]+)(/-)*/blob/([^/?#]+)/(.+) ]]; then
        HOST="${BASH_REMATCH[1]}"
        OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"
        BRANCH="${BASH_REMATCH[5]}"; FILE_PATH="${BASH_REMATCH[6]}"
        return 0
    fi
    # {host}/owner/repo/tree/branch[/subdir] or {host}/owner/repo/-/tree/branch[/subdir]
    if [[ "$input" =~ ($SUPPORTED_HOSTS)/([^/?#]+)/([^/?#]+)(/-)*/tree/([^/?#]+)(/[^?#]*)? ]]; then
        HOST="${BASH_REMATCH[1]}"
        OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"
        BRANCH="${BASH_REMATCH[5]}"; FILE_PATH="${BASH_REMATCH[6]:-}"; FILE_PATH="${FILE_PATH#/}"
        return 0
    fi
    # {host}/owner/repo/src/branch/path (Bitbucket)
    if [[ "$input" =~ (bitbucket\.org)/([^/?#]+)/([^/?#]+)/src/([^/?#]+)/(.+) ]]; then
        HOST="${BASH_REMATCH[1]}"
        OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"
        BRANCH="${BASH_REMATCH[4]}"; FILE_PATH="${BASH_REMATCH[5]}"
        return 0
    fi
    # {host}/owner/repo
    if [[ "$input" =~ ($SUPPORTED_HOSTS)/([^/?#]+)/([^/?#.]+)(\.git)?([/?#].*)?$ ]]; then
        HOST="${BASH_REMATCH[1]}"
        OWNER="${BASH_REMATCH[2]}"; REPO="${BASH_REMATCH[3]}"
        return 0
    fi
    # owner/repo (shorthand — defaults to github.com)
    if [[ "$input" =~ ^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$ ]]; then
        HOST="github.com"
        OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"
        return 0
    fi
    return 1
}

make_slug() {
    # Include host in slug to avoid collisions across platforms
    local h="$1" o="$2" r="$3"
    local short_host="${h%%.*}"  # github.com → github, gitlab.com → gitlab
    echo "${short_host}__${o}__${r}"
}

make_clone_url() {
    echo "https://${HOST}/${OWNER}/${REPO}.git"
}

# ── cache helpers ─────────────────────────────────────────────────────────────

find_cached() {
    local slug="$1" found
    found="$(find "$GH_INTERCEPT_CACHE_DIR" -maxdepth 2 -type d -name "$slug" 2>/dev/null \
        | sort -r | head -1)" || true
    if [[ -n "$found" && ! -f "${found}.cloning" ]]; then
        echo "$found"
    fi
}

is_cloning() {
    local slug="$1"
    find "$GH_INTERCEPT_CACHE_DIR" -maxdepth 2 -name "${slug}.cloning" -type f 2>/dev/null \
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
    done < <(find "$GH_INTERCEPT_CACHE_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
}

do_clone() {
    local slug="$1" clone_url="$2"; shift 2
    local clone_args=("$@")
    local target="${TODAY_DIR}/${slug}"
    local sentinel="${target}.cloning"

    mkdir -p "$TODAY_DIR"
    touch "$sentinel" 2>/dev/null || true

    if git clone "${clone_args[@]}" --quiet "$clone_url" "$target" 2>"${GH_INTERCEPT_CACHE_DIR}/gh-clone-err.log"; then
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
    [[ ! -d "$GH_INTERCEPT_CACHE_DIR" ]] && echo "(cache empty)" && return
    echo "Cache: $GH_INTERCEPT_CACHE_DIR"; echo ""
    while IFS= read -r -d '' date_dir; do
        local repos=()
        while IFS= read -r -d '' repo_dir; do
            local label
            label="$(basename "$repo_dir" | sed 's/__/\//g')"
            [[ -f "${repo_dir}/.cloning" ]] && label+=" (cloning...)"
            repos+=("$label")
        done < <(find "$date_dir" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
        [[ ${#repos[@]} -gt 0 ]] && echo "$(basename "$date_dir"):" && printf '  %s\n' "${repos[@]}"
    done < <(find "$GH_INTERCEPT_CACHE_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null | sort -rz)
}

cmd_evict() {
    parse_repo_ref "$1" || die "Cannot parse: $1"
    local slug
    slug="$(make_slug "$HOST" "$OWNER" "$REPO")"
    local found
    found="$(find "$GH_INTERCEPT_CACHE_DIR" -maxdepth 2 -type d -name "$slug" 2>/dev/null | head -1)"
    if [[ -n "$found" ]]; then
        rm -rf "$found"; rmdir "$(dirname "$found")" 2>/dev/null || true
        echo "Evicted: $found" >&2
    else
        echo "Not cached: $1" >&2
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────

# Allow sourcing for tests: GH_CACHE_SOURCED=1 source gh-cache.sh
[[ "${GH_CACHE_SOURCED:-}" == "1" ]] && return 0 2>/dev/null || true

case "${1:-}" in
    --list)    cmd_list; exit 0 ;;
    --evict)   [[ -z "${2:-}" ]] && die "Usage: --evict <owner/repo>"; cmd_evict "$2"; exit 0 ;;
    --background)
        # Fire-and-forget: parse, check, clone async, exit immediately
        [[ -z "${2:-}" ]] && die "Usage: --background <url-or-owner/repo>"
        parse_repo_ref "$2" || exit 0  # unsupported URL — silently exit
        SLUG="$(make_slug "$HOST" "$OWNER" "$REPO")"
        EXISTING="$(find_cached "$SLUG")" || true
        [[ -n "$EXISTING" ]] && exit 0  # already cached
        CLONING="$(is_cloning "$SLUG")" || true
        [[ -n "$CLONING" ]] && exit 0  # already in progress
        CLONE_URL="$(make_clone_url)"
        CLONE_ARGS=(--depth 1 --filter=blob:limit=${CLAUDE_PLUGIN_MAX_FILE_SIZE})
        [[ -n "$BRANCH" ]] && CLONE_ARGS+=(--branch "$BRANCH")
        mkdir -p "$TODAY_DIR"
        # Launch detached subprocess
        (do_clone "$SLUG" "$CLONE_URL" "${CLONE_ARGS[@]}" </dev/null &>"${GH_INTERCEPT_CACHE_DIR}/gh-clone-${SLUG}.log") &
        disown
        exit 0 ;;
    "")
        die "Usage: gh-cache.sh <url-or-owner/repo> [--branch <branch>]" ;;
esac

# Synchronous: ensure cloned and return path
INPUT="$1"
BRANCH_OVERRIDE=""
[[ "${2:-}" == "--branch" ]] && BRANCH_OVERRIDE="${3:-}"

parse_repo_ref "$INPUT" || die "Cannot parse reference: $INPUT"
[[ -n "$BRANCH_OVERRIDE" ]] && BRANCH="$BRANCH_OVERRIDE"

SLUG="$(make_slug "$HOST" "$OWNER" "$REPO")"
CLONE_URL="$(make_clone_url)"
CLONE_ARGS=(--depth 1 --filter=blob:limit=${CLAUDE_PLUGIN_MAX_FILE_SIZE})
[[ -n "$BRANCH" ]] && CLONE_ARGS+=(--branch "$BRANCH")

mkdir -p "$TODAY_DIR"
EXISTING="$(find_cached "$SLUG")" || true

if [[ -n "$EXISTING" ]]; then
    if [[ "$EXISTING" != "${TODAY_DIR}/${SLUG}" ]]; then
        echo "[gh-cache] Hit (moving to today): ${HOST}/${OWNER}/${REPO}" >&2
        mv "$EXISTING" "${TODAY_DIR}/${SLUG}"
        rmdir "$(dirname "$EXISTING")" 2>/dev/null || true
    else
        echo "[gh-cache] Hit: ${HOST}/${OWNER}/${REPO}" >&2
    fi
elif [[ -n "$(is_cloning "$SLUG")" ]]; then
    die "Clone in progress for ${HOST}/${OWNER}/${REPO} — try again shortly"
else
    echo "[gh-cache] Cloning ${HOST}/${OWNER}/${REPO}${BRANCH:+ @ ${BRANCH}} ..." >&2
    do_clone "$SLUG" "$CLONE_URL" "${CLONE_ARGS[@]}"
fi

REPO_DIR="${TODAY_DIR}/${SLUG}"
[[ -n "$FILE_PATH" ]] && echo "${REPO_DIR}/${FILE_PATH}" || echo "$REPO_DIR"

prune_old
