#!/usr/bin/env bash
# Tests for gh-intercept hooks
set -euo pipefail

HOOKS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../hooks" && pwd)"
PASS=0; FAIL=0

CACHE_DIR="$(mktemp -d)"
TODAY="$(date +%Y-%m-%d)"
trap 'rm -rf "$CACHE_DIR"' EXIT

make_cache() {
    local slug="$1" file_path="${2:-}"
    mkdir -p "${CACHE_DIR}/${TODAY}/${slug}"
    if [[ -n "$file_path" ]]; then
        mkdir -p "$(dirname "${CACHE_DIR}/${TODAY}/${slug}/${file_path}")"
        touch "${CACHE_DIR}/${TODAY}/${slug}/${file_path}"
    fi
}

run_hook() {
    GH_INTERCEPT_CACHE_DIR="$CACHE_DIR" bash "${HOOKS_DIR}/$1" <<< "$2" 2>/dev/null || true
}

ok() {
    local name="$1" out="$2" pat="$3"
    if echo "$out" | grep -q "$pat"; then
        echo "  PASS: $name"; PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"; echo "    expected pattern: $pat"; echo "    got: $out"; FAIL=$((FAIL + 1))
    fi
}

empty() {
    local name="$1" out="$2"
    if [[ -z "$out" ]]; then
        echo "  PASS: $name"; PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (expected empty)"; echo "    got: $out"; FAIL=$((FAIL + 1))
    fi
}

exits0() {
    local name="$1"
    if run_hook "$2" "$3" > /dev/null; then
        echo "  PASS: $name"; PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (non-zero exit)"; FAIL=$((FAIL + 1))
    fi
}

# ── setup ─────────────────────────────────────────────────────────────────────
make_cache "github__kapicorp__kapitan" "kapitan/inputs/jsonnet.py"
make_cache "gitlab__myorg__myrepo"

# ── notify-cached-bash.sh ─────────────────────────────────────────────────────
echo "=== notify-cached-bash.sh ==="

ok "gh api contents — cached file" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"gh api repos/kapicorp/kapitan/contents/kapitan/inputs/jsonnet.py"}}')" \
    "kapitan/inputs/jsonnet.py"

ok "gh api git/trees — cached repo" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"gh api repos/kapicorp/kapitan/git/trees/HEAD"}}')" \
    "kapicorp/kapitan"

ok "gh repo view — cached repo" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"gh repo view kapicorp/kapitan"}}')" \
    "kapicorp/kapitan"

ok "curl raw.githubusercontent.com — cached file" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"curl https://raw.githubusercontent.com/kapicorp/kapitan/master/kapitan/inputs/jsonnet.py"}}')" \
    "kapitan/inputs/jsonnet.py"

ok "curl -fsSL — cached file" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"curl -fsSL https://raw.githubusercontent.com/kapicorp/kapitan/master/kapitan/inputs/jsonnet.py"}}')" \
    "kapitan/inputs/jsonnet.py"

ok "wget raw.githubusercontent.com — cached file" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"wget https://raw.githubusercontent.com/kapicorp/kapitan/master/kapitan/inputs/jsonnet.py"}}')" \
    "kapitan/inputs/jsonnet.py"

ok "git clone github.com — cached repo" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"git clone https://github.com/kapicorp/kapitan.git"}}')" \
    "kapicorp/kapitan"

ok "gh release download -R — cached repo" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"gh release download -R kapicorp/kapitan"}}')" \
    "kapicorp/kapitan"

ok "gh run download -R — cached repo" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"gh run download 12345 -R kapicorp/kapitan"}}')" \
    "kapicorp/kapitan"

ok "curl gitlab.com — cached repo" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"curl https://gitlab.com/myorg/myrepo/some/path"}}')" \
    "myorg/myrepo"

ok "curl api.github.com contents — cached file" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"curl https://api.github.com/repos/kapicorp/kapitan/contents/kapitan/inputs/jsonnet.py"}}')" \
    "kapitan/inputs/jsonnet.py"

ok "curl api.github.com contents — cached repo" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"curl -s https://api.github.com/repos/kapicorp/kapitan/contents/"}}')" \
    "kapicorp/kapitan"

ok "curl -s api.github.com repos — cached repo" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"curl -s https://api.github.com/repos/kapicorp/kapitan"}}')" \
    "kapicorp/kapitan"

empty "curl api.github.com uncached — no note" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"curl -s https://api.github.com/repos/other/notcached/contents/"}}')"

empty "uncached repo — no note" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"curl https://raw.githubusercontent.com/other/notcached/main/file.py"}}')"

empty "unrelated command — no note" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":"ls -la"}}')"

empty "empty command — no note" \
    "$(run_hook notify-cached-bash.sh '{"tool_input":{"command":""}}')"

# ── notify-cached-websearch.sh ────────────────────────────────────────────────
echo ""
echo "=== notify-cached-websearch.sh ==="

ok "query with github.com/owner/repo — cached" \
    "$(run_hook notify-cached-websearch.sh '{"tool_input":{"query":"github.com/kapicorp/kapitan python deps"}}')" \
    "kapicorp/kapitan"

empty "query no host — no note" \
    "$(run_hook notify-cached-websearch.sh '{"tool_input":{"query":"kapitan config management"}}')"

empty "query uncached repo — no note" \
    "$(run_hook notify-cached-websearch.sh '{"tool_input":{"query":"github.com/other/notcached"}}')"

# ── clone-on-gh-api.sh (exit code only) ──────────────────────────────────────
echo ""
echo "=== clone-on-gh-api.sh (exit 0 checks) ==="

exits0 "gh api repos" notify-cached-bash.sh \
    '{"tool_input":{"command":"gh api repos/kapicorp/kapitan"}}'

exits0 "curl" clone-on-gh-api.sh \
    '{"tool_input":{"command":"curl https://raw.githubusercontent.com/kapicorp/kapitan/master/README.md"}}'

exits0 "wget" clone-on-gh-api.sh \
    '{"tool_input":{"command":"wget https://raw.githubusercontent.com/kapicorp/kapitan/master/README.md"}}'

exits0 "git clone" clone-on-gh-api.sh \
    '{"tool_input":{"command":"git clone https://github.com/kapicorp/kapitan.git"}}'

exits0 "gh release download -R" clone-on-gh-api.sh \
    '{"tool_input":{"command":"gh release download -R kapicorp/kapitan"}}'

exits0 "unrelated command" clone-on-gh-api.sh \
    '{"tool_input":{"command":"ls -la"}}'

# ── results ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
