---
name: dotagents-files
description: >-
  Use when creating or editing agent files that must conform to the DotAgents
  protocol (dotagentsprotocol.com): "set up a .agents directory", "create
  .agents agent files", "add a sub-agent profile / agent.md", "author
  agents.md", "add a skill under skills/", "write mcp.json", "dotagents
  protocol", "add a repeat task / task.md", or "write a memory file /
  memories/". The protocol is a filesystem directory convention: conformance is
  placing files at the right paths with simple `key: value` frontmatter. It is
  NOT about @-directives — no @agents/@skills/@commands/@mcp_servers/@hooks
  grammar exists in this spec, so do not invent syntax. NOT for: editing a
  repo-root AGENTS.md or existing skill/agent content — use writing-for-agents
  or skill-authoring; Claude/plugin-specific agent authoring (subagents, agent
  tools, colors) — use agent-development.
---

# DotAgents Files

The DotAgents spec (the "agents Protocol", DRAFT 2026-02-24) is a filesystem
  directory convention for agent config and content. Conformance = right path +
  simple `---` frontmatter. No `@`-directive blocks, no tool-specific grammar.
  The spec calls itself "a convergence point, not a replacement" for existing
  standards. Ecosystem mapping: MCP → `mcp.json`; AGENTS.md → `agents.md`;
  Skills → `skills/*/skill.md`; Sub-Agents → `agents/*/agent.md`; ACP →
  agent profiles; Tasks → `tasks/*/task.md`; Memories → `memories/*.md`.

Use this skill when a task creates or edits any of those files. Invent nothing
  beyond what is shown below: no fields, no grammar, no file names.

## Decide where files live

The protocol defines exactly two layers with overlay semantics:

1. `~/.agents/` — global layer, canonical base config.
2. `<project>/.agents/` — workspace layer, optional overrides, commit to git.

Merge order, verbatim from the spec:

```
defaults ← config.json ← ~/.agents ← ./.agents
```

JSON shallow-merges by key; `skills`/`memories`/`agents`/`tasks` merge by ID,
  workspace wins. The workspace layer is only discovered if already present —
  "safe by default". Pick: rules for every session → `~/.agents`; per-project
  instructions that ship with the repo → `./.agents` (only when the owner
  wants it — discovery is off until it exists). `nix/dotagents/` is
  packaging/deploy machinery (home-manager switch), NOT a protocol layer and NOT
  part of the merge order above — see Deploy note.

## Canonical layout

```
.agents/
├── agents.md            # instructions (AGENTS.md compatible)
├── system-prompt.md     # system prompt
├── mcp.json             # MCP server configuration
├── models.json          # model presets & provider keys
├── skills/
│   └── code-review/
│       └── skill.md    # skill definition
├── agents/
│   └── code-reviewer/
│       └── agent.md   # sub-agent profile
├── tasks/
│   └── daily-code-review/
│       └── task.md    # repeat task
└── memories/
    └── project-arch.md  # persistent memory
```

The full spec layout also lists settings (`speakmcp-settings.json` /
  `dotagents-settings.json`), `layouts/ui.json`, and an auto-managed
  `.backups/`. Those settings/layout files are out of scope for hand-authoring.
  Optional `agents/<id>/config.json` is NOT out of scope — it gets its own
  recipe below.

## Frontmatter and config rules

Content files = `---` frontmatter + markdown. Config files (`mcp.json`,
  `models.json`, `agents/<id>/config.json`) = plain JSON, never frontmatter.
  Frontmatter rule, verbatim from the spec:

> Uses `---` fences with simple `key: value` lines. Not full YAML — no
> external dependencies. Values can be quoted. List fields accept CSV
> (`tags: a, b, c`) or JSON arrays (`tags: ["a", "b"]`). Keys are sorted
> deterministically for clean diffs.

So: flat `key: value` lines only — no nested maps, no `- ` list lines, no YAML
  anchors. Sort keys alphabetically in files you author. For `skills/<id>/`,
  `agents/<id>/`, `tasks/<id>/`, keep `id` lowercase-hyphen and matching the
  folder name (the reference implementation defaults `id` from the folder).
  Memories are folder-less flat files — see the memories recipe for their id
  convention. Never emit `@agents`/`@skills`/`@commands`/`@mcp_servers`/`@hooks`
  blocks — that grammar is not part of this protocol.

## Authoring recipes

### agents.md — project guidelines
`agents.md` is "AGENTS.md compatible" plain markdown (sections, rules,
  commands). Optional frontmatter `kind: agents`.

```markdown
---
kind: agents
---

# Project Guidelines

## Build & Test

- Run the test suite before pushing.
- Lint must pass; fix warnings, do not silence them.
```

### skills/<skill-id>/skill.md — skill definition
Path `skills/<skill-id>/skill.md`; folder name = skill id (lowercase-hyphen).
  Fields on the spec site: `id`, `name`, `description`, `enabled: true`. Keys
  sorted — passes this skill's own checklist:

```markdown
---
description: Thorough code review
enabled: true
id: code-review
name: Code Review Expert
---

Review code changes for:
- Security vulnerabilities
- Performance implications
- Test coverage gaps
```

The spec's own published sample is unsorted (`id, name, description, enabled`)
  — that is illustrative only; the spec's sorting rule and this skill's
  checklist want the alphabetical order above. The spec lowercases the file
  (`skill.md`); the Anthropic Skills standard capitalizes `SKILL.md`. Pick one
  spelling per repo, stay consistent on case-sensitive filesystems.

### agents/<agent-id>/agent.md — sub-agent profile
Path `agents/<agent-id>/agent.md`. Identity fields in frontmatter; body is the
  agent's system prompt, second person. Spec example values: `role`
  `delegation-target`, `connection-type` `internal`.

```markdown
---
connection-type: internal
description: Reviews code changes
enabled: true
id: code-reviewer
name: Code Reviewer
role: delegation-target
---

You are a code review specialist. Focus on security vulnerabilities,
performance, and test coverage.
```

Optional sibling `agents/<id>/config.json` nests tool/model/connection; leave it
  out unless the target consumer documents it.

### tasks/<task-id>/task.md — repeat task
Path `tasks/<task-id>/task.md`; folder name = task id (lowercase-hyphen).
  Frontmatter: `kind: task`, `id`, `name`, `intervalMinutes`, `enabled`,
  `runOnStartup`, optional `profileId`. Body = the prompt run on schedule.
  `profileId` semantics are undefined by the spec (opaque external profile
  reference) — do not invent a link to a local `agents/` id:

```markdown
---
enabled: true
id: daily-code-review
intervalMinutes: 1440
kind: task
name: Daily Code Review
profileId: abc-123
runOnStartup: false
---

Review unmerged PRs. Flag security, performance, and test-coverage gaps.
```

### memories/<name>.md — persistent memory
Folder-less flat file under `memories/`, one per memory; the filename is NOT the
  `id`. Spec-listed frontmatter fields: `id`, `title`, `content`, `importance`
  (e.g. `high`), `tags` (CSV or JSON array). Markdown below the fence is the
  remembered content. The spec shows underscore ids (e.g. `arch_001`) with no
  published name regex — the lowercase-hyphen/folder rule does NOT apply here:

```markdown
---
content: Architecture decisions
id: arch_001
importance: high
tags: architecture, decisions
title: Project Architecture
---

Control plane talks to agents over stdio. State lives in `~/.agents/state`;
never commit it.
```

### mcp.json — MCP server config
Plain JSON: `{ "mcpServers": { "<name>": { ... } } }`. stdio servers use
  `command` + `args`; HTTP servers use `url`. Spec site example (verbatim):

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@mcp/server-filesystem"],
      "transport": "stdio"
    },
    "github": {
      "url": "https://api.github.com/mcp",
      "transport": "streamable-http"
    }
  }
}
```

Spec site spells HTTP transport `streamable-http`; the reference impl spells it
  `streamableHttp`. Pick one spelling per repo, note the mismatch, do not mix.

### agents/<id>/config.json — agent tool/model/connection
Optional, plain JSON. Verbatim spec site example:

```json
{
  "toolConfig": {
    "disabledServers": ["filesystem"],
    "enabledBuiltinTools": ["mark_work_complete"]
  },
  "modelConfig": {
    "mcpToolsProviderId": "openai",
    "mcpToolsOpenaiModel": "gpt-4o"
  },
  "connection": {
    "type": "stdio",
    "command": "my-agent",
    "args": ["--mode", "review"]
  }
}
```

## Authoring workflow

1. Pick the target layer and exact path (Decide where files live + Canonical
  layout). Confirm `./.agents` already exists before writing to it.
2. Create the directory chain: `skills/<id>/`, `agents/<id>/`, `tasks/<id>/`, or
  none for `memories/*.md`. Name files per the layout; the folder name equals
  the artifact `id`.
3. Write frontmatter: `---` fence, flat `key: value` lines, keys sorted, lists
  as CSV or JSON arrays. Config files (`mcp.json`, `config.json`,
  `models.json`): plain JSON, no frontmatter.
4. Write the body: plain markdown, imperative (for agents: second-person system
  prompt).
5. Verify conformance against this checklist:

- Right path? File sits at the canonical path in the chosen layer;
  skill/agent/task folders match their `id`.
- Frontmatter flat + sorted? Only `---` fences + `key: value` lines; no nested
  YAML, no `- ` list lines; keys alphabetical.
- `id` matches folder? For skills/agents/tasks only: lowercase-hyphen, identical
  to the directory name. Memories: folder-less, id independent of filename.
- No @-directives? No `@agents`/`@skills`/`@commands`/`@mcp_servers`/`@hooks`
  blocks anywhere in the files.
- Plain JSON config? `mcp.json` / `config.json` are JSON, not frontmatter.
- Workspace rule respected? `./.agents` only when already present or owner
  consented; otherwise global `~/.agents`.
- Case consistent? One `skill.md`/`SKILL.md` spelling per repo; one
  `streamable-http`/`streamableHttp` spelling per repo.
- Nothing invented? No fields, values, or file names beyond the spec examples.

## Known spec ambiguities

- DRAFT (2026-02-24), no published version number — do not claim stable
  adoption.
- `skill.md` (spec) vs `SKILL.md` (Anthropic Skills) — pick one per repo.
- `memories/` (spec) vs `knowledge/` (reference app) — follow the SPEC
  (`memories/`) unless the target consumer documents `knowledge/`.
- `connection-type` in `agent.md` frontmatter vs `connection.type` in
  `config.json` both appear. Site example puts identity fields in `agent.md`
  frontmatter and MAY repeat connection in `config.json`. Recommend:
  identity/`role`/`connection-type` in `agent.md`; no `config.json` unless the
  consumer documents it.
- Settings file named `speakmcp-settings.json` in one spec tree vs
  `dotagents-settings.json` elsewhere — not hand-authored, ignore.
- No required-field lists or name regexes published at spec level. For
  skills/agents/tasks, default `id` lowercase-hyphen to the folder name; memory
  ids (e.g. `arch_001`) are independent of filename.
- Tool support across Claude Code / Cursor / Codex / OpenCode is only claimed by
  the protocol author's own app repo, not independently verified. Phrase
  portability as "designed to be", not "works in".

## Deploy note for this ecosystem

This skill ships from the `nix` repo's `dotagents/` tree; home-manager deploys
  it to both `~/.config/opencode/skills/` and `~/.claude/skills/`. To author a
  NEW reusable skill/agent/global rule here, drop the file under
  `nix/dotagents/skills/<name>/SKILL.md` (or
  `nix/dotagents/agents/<name>/agent.md`, `nix/dotagents/agents.md`) and run
  `home-manager switch` — no nix edits needed. Per-project agent config in a
  repo: follow the protocol — create `./.agents/` (workspace layer) and/or the
  repo root `AGENTS.md`; `agents.md` is "AGENTS.md compatible". Repos in this
  ecosystem conventionally use a root `AGENTS.md` that opencode/claude read
  directly — prefer editing that for repo-local rules over duplicating into a
  workspace `.agents/agents.md`.
