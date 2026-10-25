# pstack in OpenCode

pstack skills use Cursor names. In OpenCode, read this file once per session, then map each Cursor name in a skill with the tables below. `<pstack>` means the folder that holds `skills/` and `docs/`. If a Cursor field has no row, drop it and say so. Never pass a field or value the tool schema rejects. Call tools by their OpenCode 2.x names: the command tool is `shell`, not `bash`, and the child-session tool is `subagent`.

## Tools

| Cursor | OpenCode |
| --- | --- |
| `Task` | `subagent`, arguments `agent`, `description`, `prompt`. It takes no model; see Models. A foreground call waits for the result. |
| `AskQuestion` | `question`, with a short header, prompt, and choices. In a non-interactive run it is absent, so ask in plain text. |
| Open a todolist | OpenCode 2.x has no todo tool. Keep the list in your reply and update it at each phase. |
| Run another pstack skill (`/name` or "the **name** skill") | Call the `skill` tool with `{"id": "<name>"}` when the skill is installed, else `Read` `<pstack>/skills/<name>/SKILL.md` and follow it. When you tell the user to type it, write `/name` only if a command wrapper is installed. |
| `Grep`, `Glob` | The `grep` and `glob` tools exist as-is. |

## Subagent fields

| Cursor | OpenCode |
| --- | --- |
| `subagent_type: generalPurpose` | `agent: "general"`, the built-in research subagent. |
| `poteto-agent`, `comment-sicko` | Install `agents/poteto-agent.md` and `agents/comment-sicko.md` into `~/.config/opencode/agents/` with `mode: subagent` added to their frontmatter, then pass `agent: "poteto-agent"` or `agent: "comment-sicko"`. |
| `readonly: true` | `agent: "explore"`, the built-in read-only subagent. It cannot edit, and you check `git status` afterward. |
| `readonly: false` | `agent: "general"`, or omit `agent` for the default child session. |
| `environment: "cloud"` | A local `git worktree` per writer, or `/tmp/<task>/` where there is no repo. Name the branch or commit the worker checks out. OpenCode has no cloud agents. |
| `environment: "local"` | Omit. |
| `cloud_base_branch: <b>` | Tell the worker to check out `<b>` first. |
| `run_in_background: true` | Pass `background: true` on the `subagent` call. The parent is notified when the child finishes. |
| `resume` | Spawn a fresh child and paste the earlier result into its brief. The `sessionID` a child returns can continue that one child conversation; it is not a way to skip the brief. |
| `file_attachments` | List the paths in the prompt. |

## Models

| Cursor | OpenCode |
| --- | --- |
| `claude-<family>-<version>-<effort>[-fast]`, such as `claude-opus-5-5-xhigh` | A real slug from `opencode models`, in `provider/model` form, when that family is listed. Drop `-fast`. When it is not listed (the usual case), omit the model and say the seat runs on the parent model. |
| A `grok-*`, `gpt-*`, or other non-Claude slug | Same rule: a real catalog slug, or omit the model and say so. |
| `auto` or `inherit-parent` | Omit the model. An agent with no `model` inherits the parent session's model. |
| A `model` field on the `Task` call | The `subagent` tool takes no model. Set `model` in that agent's frontmatter in `~/.config/opencode/agents/<id>.md`, or accept the parent model and say so. |
| The `pstack-models.mdc` rule, `~/.cursor/rules/pstack-models.mdc` | `~/.agents/pstack-models.md`. OpenCode never loads it by itself; pstack skills read the file when they pick a model. If the file or the role's line is missing, use the skill's default slug. |
| A role value `<model> <effort>`, such as `opus high` | `provider/model`, plus `#variant` only when `opencode models` lists that variant. With no listed variant, keep the slug and treat the effort as advisory. |

## setup-pstack

OpenCode does not load the model rule into sessions, so `setup-pstack` writes a file the skills read. Follow its steps with these changes:

- Detect. The detected models are the `provider/model` slugs that `opencode models` lists, with each `#variant` form a distinct slug. Never write a slug the command did not list. `inherit-parent` and `auto` are always valid and mean the parent model.
- Defaults. Map each default slug with the rows above: `claude-opus-5-5-xhigh` and `grok-4.7-xhigh-fast` become `inherit-parent` unless their families are actually in the catalog.
- Write. Write `~/.agents/pstack-models.md` with the comment lines, the `# budget` line, and one line per role from step 5. Overwrite the whole file. Never put the role lines in `AGENTS.md`; OpenCode loads that file into every session, and the lines belong to the file the skills read.
- Budget. The effort ladder exists only where `opencode models` lists `#variant` forms. Without them, record the budget label as advisory and keep every slug unchanged. Never fabricate a suffixed slug.

## Paths

| Cursor | OpenCode |
| --- | --- |
| `.cursor/skills/`, `~/.cursor/skills/` | `.opencode/skills/`, `~/.config/opencode/skills/`. OpenCode also scans `.claude/skills/` and `.agents/skills/`. The skill id is the folder name. |
| `~/.cursor/plugins/`, `.cursor-plugin/plugin.json` | No plugin system. Copy each `skills/<name>/` folder into a skills dir, and the two `agents/*.md` files into `~/.config/opencode/agents/` with `mode: subagent`. A slash command needs a `~/.config/opencode/commands/<name>.md` wrapper whose body loads the skill. |
| `.cursor/rules/*.mdc`, always-applied rules | `AGENTS.md` at the project root, and `~/.config/opencode/AGENTS.md` global. OpenCode loads both into every session. The model rule is the exception. See Models. |
| `https://github.com/cursor/plugins/blob/main/pstack/<path>` | `<pstack>/<path>` when that file exists. The tree ships the skills, `docs/guide/`, and `README.md`. Read the local copy and never fetch it. Give the user the URL when they need a link. |
| Transcripts in `~/.cursor/projects/<slug>/agent-transcripts/` | Sessions live in the SQLite store `~/.local/share/opencode/opencode.db`. List them with `opencode session list` and export one with `opencode session export <sessionID>`. Read only this workspace's sessions. |

## Cursor-only features

OpenCode has no Cursor Automations, Bugbot, Cursor cloud agents, or built-in PR tool. When a step needs one, put one line in your reply, `Skipped in OpenCode: <step>. <reason>.`, then go on to the next step. Do not stop, ask, or retry. When a later step needs what the skipped step made, such as a URL or a key, leave a placeholder and name it in the line.

| Cursor | OpenCode |
| --- | --- |
| Cursor Automations: routines, `update_state` routine calls, `api2.cursor.sh/automations` webhooks, routine wakes, and `SendToUser` secret requests | Skip with the line. The `automations/` folder ships as dormant source; a workflow runs only when a person invokes it by hand. |
| Bugbot | Bugbot comments on a GitHub PR are ordinary review threads, so triage them with the forge command that the step gives. Skip a step that starts, waits for, or configures Bugbot when the PR has no Bugbot check or comment. |
| Cursor cloud agents | `environment: "cloud"` maps to a worktree, as in Subagent fields. Skip a step that needs the cloud agent itself, such as its dashboard status or its own machine. |
| A built-in PR tool | Use the forge command that the step gives, such as `gh pr create`. That is not a skip, so write no line. |
