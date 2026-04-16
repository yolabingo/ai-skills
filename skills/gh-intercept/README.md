# gh-intercept

Intercept remote Git host file access and serve from a local shallow-clone cache. Repos are cloned in the background on first access — subsequent reads use local files instead of HTTP.

## Install

```bash
claude plugin marketplace add yolabingo/ai-skills
claude plugin install gh-intercept
```

## What it does

When you fetch a URL from any supported Git host (or run `gh api`/`gh repo view`), gh-intercept:

1. **PostToolUse hooks** kick off a background `git clone --depth 1` of the repo
2. **PreToolUse hooks** check if the repo is already cached and suggest using local files instead
3. **gh-cache.sh** manages the cache — cloning, listing, evicting, and auto-pruning repos older than 1 month

All hooks are non-blocking. They never prevent tool execution — just provide context and trigger side effects.

## Supported platforms

- **GitHub** (github.com, raw.githubusercontent.com)
- **GitLab** (gitlab.com)
- **Bitbucket** (bitbucket.org)
- **Codeberg** (codeberg.org)

## How it works

```
WebFetch gitlab.com/owner/repo/-/blob/main/file.py
    ↓
PostToolUse hook → background: git clone --depth 1 → /var/tmp/claude/gh-repo-cache/
    ↓
Next access:
PreToolUse hook → "repo cached at /var/tmp/claude/gh-repo-cache/2026-04-15/gitlab__owner__repo/"
    ↓
Claude uses Read/Grep/Glob on local clone instead of HTTP
```

## Cache management

```bash
# List cached repos
gh-cache.sh --list

# Clone a repo (sync) — owner/repo shorthand defaults to GitHub
gh-cache.sh owner/repo

# Clone from any supported host
gh-cache.sh https://gitlab.com/owner/repo
gh-cache.sh https://bitbucket.org/owner/repo

# Clone specific branch
gh-cache.sh owner/repo --branch develop

# Remove a repo from cache
gh-cache.sh --evict owner/repo
```

Cache location: `/var/tmp/claude/gh-repo-cache/YYYY-MM-DD/<host>__<owner>__<repo>/`

Repos not accessed for 30+ days are pruned automatically.

## Configuration

Set via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_PLUGIN_RETENTION_DAYS` | `30` | Days before unused repos are pruned |
| `CLAUDE_PLUGIN_MAX_FILE_SIZE` | `200k` | Max blob size for shallow clones (git `--filter=blob:limit=`) |

Example:
```bash
export CLAUDE_PLUGIN_RETENTION_DAYS=7
export CLAUDE_PLUGIN_MAX_FILE_SIZE=500k
```

## Plugin structure

```
gh-intercept/
  .claude-plugin/
    plugin.json           # Plugin metadata
    marketplace.json      # Marketplace listing
  hooks/
    hooks.json            # Hook definitions (Pre/PostToolUse)
    notify-cached.sh      # PreToolUse: surface local path for WebFetch
    notify-cached-bash.sh # PreToolUse: surface local path for gh api/repo
    clone-on-fetch.sh     # PostToolUse: background clone on WebFetch
    clone-on-gh-api.sh    # PostToolUse: background clone on gh api/repo
  scripts/
    gh-cache.sh           # Core cache manager (multi-platform)
  skills/
    gh-search/
      SKILL.md            # Claude instructions for cache-first workflow
```

## License

[Apache-2.0](../../LICENSE)
