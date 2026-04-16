# Roadmap: ai-skills

## Overview

Build a public repository of cross-platform AI coding skills, starting with marketplace structure and core skills, then adding Codex cross-platform support and contribution workflows.

## Current Milestone

**v0.1 Initial Release** (v0.1.0)
Status: In progress
Phases: 2 of 4 complete

## Phases

| Phase | Name | Plans | Status | Completed |
|-------|------|-------|--------|-----------|
| 1 | Repository Foundation | 2 | Complete | 2026-04-15 |
| 2 | First Skills | 1 | Complete | 2026-04-15 |
| 3 | Cross-Platform Config | 1 | Not started | - |
| 4 | Contribution Workflow | 1 | Not started | - |

## Phase Details

### Phase 1: Repository Foundation

**Goal:** Working repo structure with marketplace config, package.json, and README — installable as Claude plugin marketplace (empty, but structurally valid)
**Depends on:** Nothing (first phase)
**Research:** Unlikely (patterns established during init research)

**Scope:**
- `.claude-plugin/marketplace.json` and `plugin.json`
- `package.json` with bin entry for future npx CLI
- `skills/` directory with placeholder structure
- README with project description, install instructions, skill listing

**Plans:**
- [ ] 01-01: Marketplace structure + package.json
- [ ] 01-02: README with install docs and skill template

### Phase 2: First Skills

**Goal:** 2-3 working skills installable via Claude marketplace
**Depends on:** Phase 1 (marketplace structure)
**Research:** Unlikely (SKILL.md format known)

**Scope:**
- 2-3 initial skills with SKILL.md files
- Verify marketplace install works end-to-end
- Skills follow consistent format and quality bar

**Plans:**
- [x] 02-01: Port gh-intercept plugin
- [ ] 02-02: Test marketplace install flow (deferred — requires push to GitHub)

### Phase 3: Cross-Platform Config

**Goal:** Skills work in both Claude Code and Codex
**Depends on:** Phase 2 (skills exist to add configs for)
**Research:** Likely (Codex plugin spec details)
**Research topics:** Codex .codex-plugin/ format, YAML agent config, skill invocation syntax

**Scope:**
- `.codex-plugin/` configs for each skill
- Verify skills work in Codex CLI
- Document any platform-specific differences

**Plans:**
- [ ] 03-01: Add Codex configs and verify cross-platform

### Phase 4: Contribution Workflow

**Goal:** Community can contribute skills via clear process
**Depends on:** Phase 2 (need existing skills as examples)
**Research:** Unlikely (standard open-source patterns)

**Scope:**
- CONTRIBUTING.md with skill authoring guide
- Skill template for new contributions
- PR template
- CI validation (optional)

**Plans:**
- [ ] 04-01: Contribution docs and templates

---
*Roadmap created: 2026-04-15*
*Last updated: 2026-04-15*
