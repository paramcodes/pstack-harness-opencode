# pstack OpenCode adapter

An `opencode.md` harness adapter for [pstack](https://github.com/cursor/plugins/tree/main/pstack)
(0.15.32), written for cursor/plugins' official harness mechanism — the same one that generates the
Claude Code tree from `docs/harness/claude-code.md`. Built 2026-10-25 against the OpenCode v2 docs
(tools, agents, skills, commands pages).

## What's here

| File | What it is |
|---|---|
| `opencode.md` | The adapter. Upstream home: `pstack/docs/harness/opencode.md`. Covers every Cursor term the generator checks (21 terms + skill-routing), so the coverage gate passes. |
| `generate-pstack-harness-trees.mjs` | Patched generator. Parameterized over a `TREES` list so it emits both `claude-code/` and `opencode/`. Verified: the regenerated `claude-code/` tree is byte-identical to upstream's committed one. |
| `tree/` | The generated `harness/pstack/opencode/` tree: 58 skills, agents, guide, adapter, README, LICENSE. Each Cursor-flavored skill has one injected line pointing at the adapter. |

## Fresh-system install (tested)

```bash
./install.sh            # or: PSTACK_DIR=~/somewhere ./install.sh
```

One script, verified end to end against a scratch HOME:

1. Copies `tree/` intact to `~/pstack` (default; override with `PSTACK_DIR`), so the skills'
   `../../docs/harness/opencode.md` links resolve on disk.
2. Adds `"skills": ["<PSTACK_DIR>/skills"]` to `~/.config/opencode/opencode.json` — opencode's
   documented extra-source mechanism. If the file is JSONC or node is absent, it prints the line
   to add instead of editing.
3. Installs `poteto-agent` and `comment-sicko` into `~/.config/opencode/agents/` with
   `mode: subagent` injected into their frontmatter.
4. Writes `/command` wrappers for the 57 of 58 skills that ship
   `disable-model-invocation: true` (everything except `setup-pstack` — upstream treats skills as
   user-invoked commands, and opencode v2 honors that field, so without wrappers they are only
   reachable via `@skill-id`).

Then: restart opencode, ask it to *"Read ~/pstack/skills/setup-pstack/SKILL.md and follow it"* to
write `~/.agents/pstack-models.md`, and use `/arena`, `/poteto-mode`, etc.

Update later: replace `~/pstack` + re-run the agent/wrapper steps (re-running the script does all of it).
Uninstall: delete `~/pstack`, `~/.config/opencode/agents/{poteto-agent,comment-sicko}.md`,
`~/.config/opencode/commands/*.md` from this pack, and the `skills` entry in `opencode.json`.

## Option A — keep tracking upstream (recommended for contributing)

1. Clone `cursor/plugins`, copy `opencode.md` to `pstack/docs/harness/`, replace
   `scripts/generate-pstack-harness-trees.mjs` with the one here.
2. `node scripts/generate-pstack-harness-trees.mjs` — regenerates `harness/pstack/` (both trees).
3. Commit; ideally PR it upstream (`harness/pstack/opencode/` + the two files). After that, every
   upstream sync is one merge + one generator run.

## Option B — install the generated tree as-is

```bash
# skills (skill id = folder name)
cp -r tree/skills/* ~/.config/opencode/skills/

# agents — add `mode: subagent` to each file's frontmatter (they ship Cursor frontmatter,
# and OpenCode defaults custom agents to mode: primary)
cp tree/agents/*.md ~/.config/opencode/agents/
# then edit both files: add a line `mode: subagent` under `description:`
```

Then run `/setup-pstack`-style setup once: create `~/.agents/pstack-models.md` with one
`role: model` line per role (real slugs from `opencode models`; `inherit-parent` always valid).
OpenCode does not load that file itself — the skills read it when they pick a model.

Optional slash commands (OpenCode has no skills-as-commands): for each `/name` you want, add
`~/.config/opencode/commands/name.md` whose body says "Read
`~/.config/opencode/skills/name/SKILL.md` and follow it. $ARGUMENTS".

## Notes and caveats

- **This machine already has two other pstack copies** that will collide on skill ids (OpenCode
  scans `~/.config/opencode/skills` *and* the compat dir `~/.agents/skills`): the 0.15.10 local port
  in `~/.config/opencode/skills/` and the backnotprop mirror in `~/.agents/skills/`. Installing this
  tree overwrites the port's versions of the same folders. Decide which one source owns pstack
  skills and remove the others, or the last-registered source wins per id.
- Skills with `disable-model-invocation: true` in frontmatter (e.g. `arena`) are hidden from the
  model's advertised list — OpenCode v2 honors that field — so they need a command wrapper or an
  explicit `@skill-id` mention to be invoked.
- The `subagent` tool takes no per-call model. Model choices live in agent frontmatter
  (`~/.config/opencode/agents/<id>.md`) or default to the parent model; the adapter's Models table
  says exactly this.
- Cursor-only features (Automations/Benny, Bugbot, cloud agents) are skip-with-one-line, not
  ported, per the adapter's Cursor-only features section.
- Upstream's own `check-pstack-docs.mjs` fails on pristine main today (a `/deslop` doc-link bug);
  unrelated to this adapter. `validate-plugins.mjs` needs `npm i ajv` to run at all.
