# Contributing to ai-skills

Thanks for contributing a skill! This guide walks through the structure, required files, and submission process.

## Skill Structure

Each skill lives in `skills/<skill-name>/` and follows the Claude Code plugin format:

```
skills/your-skill/
  .claude-plugin/
    plugin.json           # Required — plugin metadata
    marketplace.json      # Required — marketplace listing
  skills/
    your-skill-name/
      SKILL.md            # Required — skill instructions
  hooks/                  # Optional — lifecycle hooks
    hooks.json            # Hook definitions
    *.sh                  # Hook scripts
  scripts/                # Optional — utility scripts
```

See [skills/gh-intercept](skills/gh-intercept) for a complete example.

## Required Files

### plugin.json

```json
{
  "name": "your-skill",
  "version": "1.0.0",
  "description": "One-line description of what this skill does",
  "author": {
    "name": "Your Name"
  },
  "skills": "./skills/",
  "hooks": "./hooks/hooks.json"
}
```

### marketplace.json

```json
{
  "name": "your-skill",
  "description": "One-line description",
  "owner": {
    "name": "Your Name"
  },
  "plugins": [
    {
      "name": "your-skill",
      "description": "Description for marketplace listing",
      "version": "1.0.0",
      "source": "./",
      "category": "development",
      "keywords": ["relevant", "keywords"]
    }
  ]
}
```

### SKILL.md

```markdown
---
name: your-skill-name
description: Brief description used by Claude to decide when to invoke this skill.
---

# Your Skill Name

Instructions for Claude when this skill is active.
Include usage examples, commands, and expected behavior.
```

## Guidelines

- **No hardcoded paths.** Use `${CLAUDE_PLUGIN_ROOT}` for references to files within the plugin.
- **Keep SKILL.md focused.** Claude reads this — clear instructions produce better results.
- **Valid JSON.** Both plugin.json and marketplace.json must parse without errors.
- **Test locally.** Copy your skill to `~/.claude/skills/` and verify it works before submitting.

## Testing Locally

1. Copy your skill directory to `~/.claude/skills/your-skill/`
2. Start a new Claude Code session
3. Verify the skill loads and behaves as expected
4. Check hooks fire correctly (if applicable)

## Submitting a PR

1. Fork this repo
2. Create your skill in `skills/your-skill/`
3. Add your skill to the root `.claude-plugin/marketplace.json` plugins array
4. Update `README.md` skills table
5. Open a PR using the template

## License

By contributing, you agree your contribution is licensed under [Apache-2.0](LICENSE).
