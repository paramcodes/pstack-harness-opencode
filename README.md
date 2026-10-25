# pstack-harness-opencode

An OpenCode adapter for [pstack](https://github.com/cursor/plugins/tree/main/pstack), built on
cursor/plugins' official harness mechanism — the same one that generates the Claude Code tree from
`pstack/docs/harness/claude-code.md`. This repo tracks upstream so the adapter stays current.

## Layout

| Path | What it is |
|---|---|
| `pstack/` | Upstream `pstack/` folder, synced by `sync.sh` (mirror-style). |
| `pstack/docs/harness/opencode.md` | **Ours.** The adapter: maps every Cursor name pstack skills use to OpenCode 2.x. The generator's coverage gate fails the sync if a new Cursor term has no row here. |
| `scripts/generate-pstack-harness-trees.mjs` | **Ours.** Upstream's generator, parameterized over a `TREES` list so it emits `claude-code/` and `opencode/`. Verified: the claude-code tree regenerates byte-identical to upstream's. |
| `tree/` | The generated `harness/pstack/opencode/` tree — what `install.sh` installs. Regenerated on every sync. |
| `sync.sh` | Manual upstream sync. See below. |
| `.github/workflows/sync-upstream.yml` | Optional weekly automation: syncs and opens a PR. Nothing auto-merges. |
| `install.sh` | Fresh-system installer. |
| `UPSTREAM-SHA.txt` | The cursor/plugins commit last synced. |

## Install on a fresh system

```bash
git clone https://github.com/paramcodes/pstack-harness-opencode.git
cd pstack-harness-opencode && ./install.sh
```

The installer (tested end to end): copies `tree/` intact to `~/pstack` so the skills'
`../../docs/harness/opencode.md` links resolve; adds `"skills": ["~/pstack/skills"]` to
`~/.config/opencode/opencode.json`; installs `poteto-agent` and `comment-sicko` into
`~/.config/opencode/agents/` with `mode: subagent`; writes `/command` wrappers for the 57 of 58
skills that ship `disable-model-invocation: true` (everything except `setup-pstack` — without
wrappers those are only reachable via `@skill-id`).

Then restart opencode and ask it to *"Read ~/pstack/skills/setup-pstack/SKILL.md and follow it"* to
write `~/.agents/pstack-models.md` (per-role models; `inherit-parent` is always valid). Until then
skills use their defaults.

Uninstall: delete `~/pstack`, the two agent files, this pack's command wrappers, and the `skills`
entry in `opencode.json`.

## Tracking upstream

`git remote add upstream` elsewhere is just a bookmark — nothing fetches by itself. This repo syncs
mirror-style instead:

```bash
./sync.sh        # from the repo root
```

What it does: sparse-clones cursor/plugins at latest main, copies `pstack/` over ours (keeping our
adapter file, which upstream does not have), regenerates the trees — **the generator's coverage
gate runs here and fails loudly if upstream introduced a Cursor term the adapter has no row for** —
refreshes `tree/`, writes `UPSTREAM-SHA.txt`, and suggests a commit message. `rsync --delete`
means upstream deletions propagate; our only protected path is the adapter.

Manual cadence is whenever you feel like it. For automatic:

- `.github/workflows/sync-upstream.yml` runs the same sync every Monday 06:00 UTC (also
  triggerable from the Actions tab) and opens a **pull request** when anything changed. It never
  pushes to `main`; you review and merge. Delete the file for manual-only syncs.
- The PR only appears if the sync produced changes and the coverage gate passed. If upstream adds
  a Cursor term your adapter doesn't cover, the job fails instead of opening a PR — that's the
  signal to add a row to `pstack/docs/harness/opencode.md` and re-run.

## Contributing upstream

The two "ours" files are the entire diff against cursor/plugins' mechanism. A PR to
cursor/plugins would be: add `pstack/docs/harness/opencode.md`, apply the generator's `TREES`
parameterization, commit the generated `harness/pstack/opencode/` (their CI requires the generated
tree committed). After merge, `sync.sh` pulls your adapter from upstream and the local copy of
these files becomes redundant.

## Caveats

- The `subagent` tool takes no per-call model; model choices live in agent frontmatter or the
  parent model — the adapter's Models table says exactly this.
- Cursor-only features (Automations/Benny, Bugbot, cloud agents) are skip-with-one-line, not
  ported, per the adapter's Cursor-only features section.
- The adapter is advisory like Claude Code's: the model reads it once per session. Nothing
  enforces it the way a hard-coded port would.
