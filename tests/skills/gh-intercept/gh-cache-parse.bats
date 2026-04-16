#!/usr/bin/env bats
# Tests for gh-cache.sh URL parsing, slug generation, and cache operations.
# Requires: bats-core (brew install bats-core)

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
GH_CACHE="${SCRIPT_DIR}/../../../skills/gh-intercept/scripts/gh-cache.sh"

setup() {
    GH_CACHE_SOURCED=1 source "$GH_CACHE"
}

# ── parse_repo_ref: GitHub ───────────────────────────────────────────────────

@test "parse: github.com/owner/repo" {
    parse_repo_ref "https://github.com/dotcms/core"
    [[ "$HOST" == "github.com" ]]
    [[ "$OWNER" == "dotcms" ]]
    [[ "$REPO" == "core" ]]
    [[ -z "$BRANCH" ]]
    [[ -z "$FILE_PATH" ]]
}

@test "parse: github.com/owner/repo/blob/branch/file" {
    parse_repo_ref "https://github.com/dotcms/core/blob/main/README.md"
    [[ "$HOST" == "github.com" ]]
    [[ "$OWNER" == "dotcms" ]]
    [[ "$REPO" == "core" ]]
    [[ "$BRANCH" == "main" ]]
    [[ "$FILE_PATH" == "README.md" ]]
}

@test "parse: github.com blob with nested path" {
    parse_repo_ref "https://github.com/owner/repo/blob/develop/src/main/App.java"
    [[ "$HOST" == "github.com" ]]
    [[ "$BRANCH" == "develop" ]]
    [[ "$FILE_PATH" == "src/main/App.java" ]]
}

@test "parse: github.com/owner/repo/tree/branch" {
    parse_repo_ref "https://github.com/dotcms/core/tree/release-24.01"
    [[ "$HOST" == "github.com" ]]
    [[ "$OWNER" == "dotcms" ]]
    [[ "$REPO" == "core" ]]
    [[ "$BRANCH" == "release-24.01" ]]
}

@test "parse: github.com/owner/repo/tree/branch/subdir" {
    parse_repo_ref "https://github.com/owner/repo/tree/main/src/components"
    [[ "$HOST" == "github.com" ]]
    [[ "$BRANCH" == "main" ]]
    [[ "$FILE_PATH" == "src/components" ]]
}

@test "parse: raw.githubusercontent.com" {
    parse_repo_ref "https://raw.githubusercontent.com/dotcms/core/main/README.md"
    [[ "$HOST" == "github.com" ]]
    [[ "$OWNER" == "dotcms" ]]
    [[ "$REPO" == "core" ]]
    [[ "$BRANCH" == "main" ]]
    [[ "$FILE_PATH" == "README.md" ]]
}

@test "parse: raw.githubusercontent.com nested path" {
    parse_repo_ref "https://raw.githubusercontent.com/owner/repo/develop/src/lib/utils.ts"
    [[ "$HOST" == "github.com" ]]
    [[ "$BRANCH" == "develop" ]]
    [[ "$FILE_PATH" == "src/lib/utils.ts" ]]
}

@test "parse: github.com/owner/repo.git" {
    parse_repo_ref "https://github.com/dotcms/core.git"
    [[ "$HOST" == "github.com" ]]
    [[ "$OWNER" == "dotcms" ]]
    [[ "$REPO" == "core" ]]
}

# ── parse_repo_ref: GitLab ───────────────────────────────────────────────────

@test "parse: gitlab.com/owner/repo" {
    parse_repo_ref "https://gitlab.com/inkscape/inkscape"
    [[ "$HOST" == "gitlab.com" ]]
    [[ "$OWNER" == "inkscape" ]]
    [[ "$REPO" == "inkscape" ]]
}

@test "parse: gitlab.com/-/blob (GitLab style)" {
    parse_repo_ref "https://gitlab.com/inkscape/inkscape/-/blob/master/CMakeLists.txt"
    [[ "$HOST" == "gitlab.com" ]]
    [[ "$OWNER" == "inkscape" ]]
    [[ "$REPO" == "inkscape" ]]
    [[ "$BRANCH" == "master" ]]
    [[ "$FILE_PATH" == "CMakeLists.txt" ]]
}

@test "parse: gitlab.com/-/tree (GitLab style)" {
    parse_repo_ref "https://gitlab.com/inkscape/inkscape/-/tree/master/src"
    [[ "$HOST" == "gitlab.com" ]]
    [[ "$BRANCH" == "master" ]]
    [[ "$FILE_PATH" == "src" ]]
}

@test "parse: gitlab.com blob without dash prefix" {
    parse_repo_ref "https://gitlab.com/org/project/blob/main/file.py"
    [[ "$HOST" == "gitlab.com" ]]
    [[ "$OWNER" == "org" ]]
    [[ "$REPO" == "project" ]]
    [[ "$BRANCH" == "main" ]]
    [[ "$FILE_PATH" == "file.py" ]]
}

# ── parse_repo_ref: Bitbucket ────────────────────────────────────────────────

@test "parse: bitbucket.org/owner/repo" {
    parse_repo_ref "https://bitbucket.org/atlassian/python-bitbucket"
    [[ "$HOST" == "bitbucket.org" ]]
    [[ "$OWNER" == "atlassian" ]]
    [[ "$REPO" == "python-bitbucket" ]]
}

@test "parse: bitbucket.org/owner/repo/src/branch/file" {
    parse_repo_ref "https://bitbucket.org/atlassian/python-bitbucket/src/main/setup.py"
    [[ "$HOST" == "bitbucket.org" ]]
    [[ "$OWNER" == "atlassian" ]]
    [[ "$REPO" == "python-bitbucket" ]]
    [[ "$BRANCH" == "main" ]]
    [[ "$FILE_PATH" == "setup.py" ]]
}

# ── parse_repo_ref: Codeberg ────────────────────────────────────────────────

@test "parse: codeberg.org/owner/repo" {
    parse_repo_ref "https://codeberg.org/forgejo/forgejo"
    [[ "$HOST" == "codeberg.org" ]]
    [[ "$OWNER" == "forgejo" ]]
    [[ "$REPO" == "forgejo" ]]
}

@test "parse: codeberg.org blob (Gitea-style, same as GitHub)" {
    parse_repo_ref "https://codeberg.org/forgejo/forgejo/blob/main/Makefile"
    [[ "$HOST" == "codeberg.org" ]]
    [[ "$OWNER" == "forgejo" ]]
    [[ "$REPO" == "forgejo" ]]
    [[ "$BRANCH" == "main" ]]
    [[ "$FILE_PATH" == "Makefile" ]]
}

# ── parse_repo_ref: shorthand ────────────────────────────────────────────────

@test "parse: owner/repo shorthand defaults to github" {
    parse_repo_ref "dotcms/core"
    [[ "$HOST" == "github.com" ]]
    [[ "$OWNER" == "dotcms" ]]
    [[ "$REPO" == "core" ]]
}

@test "parse: owner/repo with dots and hyphens" {
    parse_repo_ref "some-org/my.project"
    [[ "$HOST" == "github.com" ]]
    [[ "$OWNER" == "some-org" ]]
    [[ "$REPO" == "my.project" ]]
}

# ── parse_repo_ref: failures ────────────────────────────────────────────────

@test "parse: unsupported host fails" {
    run parse_repo_ref "https://example.com/owner/repo"
    [[ "$status" -ne 0 ]]
}

@test "parse: bare word fails" {
    run parse_repo_ref "justarepo"
    [[ "$status" -ne 0 ]]
}

@test "parse: empty string fails" {
    run parse_repo_ref ""
    [[ "$status" -ne 0 ]]
}

# ── make_slug ────────────────────────────────────────────────────────────────

@test "slug: github.com produces github__ prefix" {
    result="$(make_slug "github.com" "owner" "repo")"
    [[ "$result" == "github__owner__repo" ]]
}

@test "slug: gitlab.com produces gitlab__ prefix" {
    result="$(make_slug "gitlab.com" "org" "project")"
    [[ "$result" == "gitlab__org__project" ]]
}

@test "slug: bitbucket.org produces bitbucket__ prefix" {
    result="$(make_slug "bitbucket.org" "team" "lib")"
    [[ "$result" == "bitbucket__team__lib" ]]
}

@test "slug: codeberg.org produces codeberg__ prefix" {
    result="$(make_slug "codeberg.org" "user" "proj")"
    [[ "$result" == "codeberg__user__proj" ]]
}

@test "slug: no collision across platforms" {
    slug_gh="$(make_slug "github.com" "owner" "repo")"
    slug_gl="$(make_slug "gitlab.com" "owner" "repo")"
    [[ "$slug_gh" != "$slug_gl" ]]
}

# ── make_clone_url ───────────────────────────────────────────────────────────

@test "clone url: github" {
    HOST="github.com" OWNER="dotcms" REPO="core"
    result="$(make_clone_url)"
    [[ "$result" == "https://github.com/dotcms/core.git" ]]
}

@test "clone url: gitlab" {
    HOST="gitlab.com" OWNER="inkscape" REPO="inkscape"
    result="$(make_clone_url)"
    [[ "$result" == "https://gitlab.com/inkscape/inkscape.git" ]]
}

@test "clone url: bitbucket" {
    HOST="bitbucket.org" OWNER="atlassian" REPO="python-bitbucket"
    result="$(make_clone_url)"
    [[ "$result" == "https://bitbucket.org/atlassian/python-bitbucket.git" ]]
}
