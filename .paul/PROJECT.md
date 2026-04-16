# ai-skills

## What This Is

A public repository of reusable AI skills/plugins packaged for distribution across Claude Code, Codex, and other AI coding assistants. Skills are markdown-based with cross-platform configs, distributed primarily via Claude Code's plugin marketplace with an optional npx CLI.

## Core Value

Developers can discover, install, and use curated AI coding skills across multiple AI assistants from a single source.

## Current State

| Attribute | Value |
|-----------|-------|
| Type | Application |
| Version | 0.1.0 |
| Status | In Development |
| Last Updated | 2026-04-15 |

## Requirements

### Core Features

- Curated collection of AI coding skills (Claude Code + Codex compatible)
- Plugin marketplace integration (discoverable via `claude plugin marketplace add`)
- ~~npx CLI for quick install/list/search~~ — marketplace distribution sufficient
- ~~Cross-platform skill format (Claude + Codex configs)~~ — Codex has no plugin system; Claude-only for now

### Validated (Shipped)
None yet.

### Active (In Progress)
- [ ] Plugin marketplace integration — gh-intercept ported, needs push + install test

### Planned (Next)
- First skills (Phase 2)
- Cross-platform Codex support (Phase 3)
- Contribution workflow (Phase 4)

### Out of Scope
- To be defined during /paul:plan

## Constraints

### Technical Constraints
- No hard constraints identified

### Business Constraints
- No hard constraints identified

## Key Decisions

| Decision | Rationale | Date | Status |
|----------|-----------|------|--------|
| Flat structure, no monorepo tooling | Skills are markdown files — no compile step needed | 2026-04-15 | Active |
| Dual distribution: marketplace + npx | Marketplace is primary for Claude users; npx for convenience/teams | 2026-04-15 | Active |
| Cross-platform via separate config dirs | `.claude-plugin/` and `.codex-plugin/` per established patterns | 2026-04-15 | Active |

## Success Metrics

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Skills installable via Claude marketplace | Working | - | Not started |
| Cross-platform compatibility (Claude + Codex) | N/A — Codex has no plugin system | - | Deferred |
| Contribution docs | Clear enough for community PRs | - | Not started |

## Tech Stack / Tools

| Layer | Technology | Notes |
|-------|------------|-------|
| Runtime | Node.js | For optional npx CLI only |
| Skills format | Markdown + YAML frontmatter | SKILL.md files |
| Package manager | npm | npx-native distribution |
| Registry | marketplace.json | Claude plugin marketplace config |
| Cross-platform | .claude-plugin/ + .codex-plugin/ | Separate config dirs per platform |
| Build | None / optional TS for CLI | Skills need no compilation |

---
*Created: 2026-04-15*
*Last updated: 2026-04-15 after Phase 1*
