---
name: gh-search
description: Inspect and search remote Git repositories locally using a shallow-cloned cache. Supports GitHub, GitLab, Bitbucket, and Codeberg. Before using gh api, gh repo view, or WebFetch to read remote files, check for a local clone at /var/tmp/yolabingo-ai-skills-gh-intercept-repo-dir/ and use Grep/Read/Glob tools on it instead.
---

# gh-search

Inspect and search remote Git repos locally. Supports GitHub, GitLab, Bitbucket, and Codeberg. Repos are automatically shallow-cloned in the background whenever a supported URL is fetched or a `gh api`/`gh repo view` command targets a repo. This skill handles explicit searches, file inspection, and cache management.

## Always check local cache first

Before using WebFetch, `gh api`, or `gh repo view` to inspect a remote repo, check if it's cached:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gh-cache.sh" --list
```

If cached, use `Grep`, `Read`, and `Glob` tools directly on local path — faster, zero HTTP overhead, full file contents (no API pagination).

## Ensure a repo is cloned (sync)

```bash
# From URL (any supported host)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gh-cache.sh" https://github.com/owner/repo
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gh-cache.sh" https://gitlab.com/owner/repo
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gh-cache.sh" https://bitbucket.org/owner/repo

# From owner/repo (defaults to GitHub)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gh-cache.sh" owner/repo

# Specific branch
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gh-cache.sh" owner/repo --branch develop

# Returns local repo root path on stdout
```

## Inspect remote files locally

Instead of `gh api repos/owner/repo/contents/path` or `gh api repos/owner/repo/git/trees/...`, clone the repo and use local tools:

```bash
# Clone first (if not cached)
LOCAL=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/gh-cache.sh" owner/repo)

# Then use Read, Grep, Glob directly
Read "$LOCAL/src/main/java/com/example/Router.java"
Grep "pattern" "$LOCAL"
Glob "**/*.ts" "$LOCAL"
```

Benefits over `gh api`:
- No pagination limits
- Full file contents (gh api base64-encodes and truncates large files)
- Can search across entire repo with Grep
- Works with Glob for file discovery

## Search a repo locally

```bash
rg "pattern" /var/tmp/yolabingo-ai-skills-gh-intercept-repo-dir/YYYY-MM-DD/github__owner__repo/

# File-only list
rg -l "pattern" /var/tmp/yolabingo-ai-skills-gh-intercept-repo-dir/YYYY-MM-DD/github__owner__repo/

# Type filter
rg --type java "ClassName" /var/tmp/yolabingo-ai-skills-gh-intercept-repo-dir/YYYY-MM-DD/gitlab__owner__repo/
```

## Cache management

```bash
# List all cached repos with last-used date
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gh-cache.sh" --list

# Remove a specific repo
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gh-cache.sh" --evict owner/repo
```

Repos not accessed for more than one month are pruned automatically after each sync operation.

## Cache layout

```
/var/tmp/yolabingo-ai-skills-gh-intercept-repo-dir/
  2026-04-15/          <- last-used date (moved here on access)
    github__dotcms__core/
    gitlab__owner__repo/
  2026-03-10/          <- older entries, will be pruned after 1 month
    bitbucket__owner__repo/
```

## Slug format

Host, owner, and repo joined with `__`: `github.com/dotcms/core` -> `github__dotcms__core`, `gitlab.com/org/project` -> `gitlab__org__project`

## How interception works

**WebFetch** — PostToolUse hook fires on any supported Git host URL (GitHub, GitLab, Bitbucket, Codeberg), starts `git clone --depth 1` in background. PreToolUse hook checks cache and suggests local path.

**Bash (gh api / gh repo view)** — Same pattern. PostToolUse detects `gh api repos/...` or `gh repo view owner/repo` commands and triggers background clone. PreToolUse surfaces local cache path if available.

A `.cloning` sentinel file is written during clone and removed on completion. Next time you need to inspect that repo, it's already local.
