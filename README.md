# jd-treasure-ai-skills

A public marketplace of custom skills for [Treasure AI](https://treasure.ai) / Treasure Work and Claude Code.

This repo follows the Claude Code plugin-marketplace convention: a top-level
[`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) registers one or more plugins, and each
plugin bundles one or more skills (`SKILL.md` files) under its own `skills/` directory.

## Status

Published skills:

| Plugin | Description |
|--------|-------------|
| [`time`](plugins/time) | Reports the user's current local time via IP geolocation, with a system-local-time fallback. Treasure Work skill (`/time`). |

## Structure

```
jd-treasure-ai-skills/
├── .claude-plugin/
│   └── marketplace.json      # Registry of all plugins in this marketplace
├── plugins/
│   ├── _template/            # Copy this to start a new plugin
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   └── skills/
│   │       └── example-skill/
│   │           └── SKILL.md
│   └── <your-plugin>/        # One directory per published plugin
├── CONTRIBUTING.md
└── LICENSE
```

## Using this marketplace

Add it as a marketplace source in Claude Code / Treasure Work, then install individual plugins from it. See
[CONTRIBUTING.md](CONTRIBUTING.md) for how skills are added and published.

## Adding a new skill

1. Copy `plugins/_template/` to `plugins/<your-plugin-name>/`.
2. Write your `SKILL.md` under `plugins/<your-plugin-name>/skills/<skill-name>/SKILL.md`.
3. Fill in `plugins/<your-plugin-name>/.claude-plugin/plugin.json`.
4. Register the plugin in `.claude-plugin/marketplace.json`.
5. Open a PR.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.
