# Contributing

This marketplace holds custom Claude Code / Treasure Work skills as plugins. Each plugin lives under
`plugins/<plugin-name>/` and bundles one or more `SKILL.md` files.

## Adding a new skill

1. **Copy the template**

   ```bash
   cp -r plugins/_template plugins/<your-plugin-name>
   ```

2. **Write the skill**

   Edit `plugins/<your-plugin-name>/skills/<skill-name>/SKILL.md`. Every skill needs YAML frontmatter with:

   - `name` — lowercase, hyphens/underscores, max 64 chars
   - `description` — the single most important field; controls when the skill triggers. Be specific and
     "pushy" about trigger phrases — under-triggering is more common than over-triggering.

   Keep instructions imperative, under ~200 lines where possible, and back them with 1-2 concrete
   input/output examples.

3. **Fill in the plugin manifest**

   Edit `plugins/<your-plugin-name>/.claude-plugin/plugin.json` — set `name`, `description`, and `version`
   (start at `0.1.0`).

4. **Register the plugin**

   Add an entry to the `plugins` array in `.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "your-plugin-name",
     "source": "./plugins/your-plugin-name"
   }
   ```

5. **Open a PR**

   Include a short description of what the skill does and a sample prompt that should trigger it.

## Guidelines

- One skill = one capability. Split unrelated behaviors into separate skills/plugins.
- Don't duplicate a skill that already exists in this marketplace or in Treasure Data's internal skill
  library — extend or link instead.
- No secrets, customer data, or internal-only references in a public skill. This repo is public.
