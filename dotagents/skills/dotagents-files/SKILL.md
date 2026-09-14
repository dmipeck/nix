---
name: dotagents-files
description: >-
  Use when creating or editing Cursor Authoring Format files under
  `dotagents/`: flat agents (`agents/<id>.md`), Cursor-pure skills
  (`skills/<id>/SKILL.md`), `.mdc` rules, or Cursor-shaped `mcp.json`.
  Triggers: "add a subagent", "author an agent.md", "write a skill under
  dotagents/skills", "add a rule .mdc", "edit mcp.json", "Authoring Format",
  "metadata.opencode", "Common Model". NOT for: repo-root AGENTS.md content
  quality — use writing-for-agents; Claude/plugin-only agent tooling — use
  agent-development; DotAgents protocol / OpenCode dialect as on-disk SoT.
---

# DotAgents Files (Cursor Authoring Format)

On-disk **Authoring Format** under `vendor/nix/dotagents/` is the Cursor
dialect: flat agents, Cursor-pure skills, `.mdc` rules, Cursor-shaped
`mcp.json`. Eval parses into a **Common Model**; **Adapter Emit**
passthroughs to Cursor and converts to OpenCode/Claude. OpenCode dialect and
DotAgents protocol flat frontmatter are **not** the source of truth.

Use this skill to create or edit those files. Invent nothing beyond the
recipes and glossary below.

## Glossary

**Authoring Format**:
On-disk Cursor dialect SoT: `agents/<id>.md`,
`skills/<id>/SKILL.md`, `rules/*.mdc`, Cursor-shaped `mcp.json`.

**Metadata**:
Agent frontmatter field `metadata` holding nested `opencode` /
`claude` portability knobs. Not a separate `meta` key. Skills stay
Cursor-pure (no portability nests).

**Common Model**:
Structured Nix attrs from parsing Authoring Format (agents, skills,
MCP, rules) before Adapter Emit.

**Adapter Emit**:
Per-consumer render: Cursor = passthrough (agents: documented fields
only, strip `metadata`); OpenCode/Claude = convert from Common Model +
`metadata.*`.

**MCP Server Definition**:
Cursor-shaped entry in authored `mcp.json` (`stdio` / `url` /
`headers` / `auth` / `env`).

**MCP Instance**:
Per-user Nix overlays under `dotagents.mcps.<name>` (enable, secrets,
URL/OAuth). Tool allowlists stay Nix-side, not non-Cursor keys in
`mcp.json`.

## Where files live

Author under the library tree `vendor/nix/dotagents/` (this repo when working
in `dmipeck/nix`). home-manager deploys via adapters after `home-manager
switch`. Upstream/collection skills stay Nix packages under
`nix/dotagents/skills/*.nix` — do **not** rewrite those into Authoring
Format; only local `dotagents/skills/` is Cursor SoT.

```
dotagents/
├── agents/
│   └── github.md           # flat agent (stem = name)
├── skills/
│   └── code-review/
│       └── SKILL.md        # Cursor-pure skill
├── rules/
│   ├── be-concise.mdc      # Cursor rules
│   └── …                   # more alwaysApply .mdc rules
└── mcp.json                # MCP Server Definitions
```

## Authoring recipes

### agents/<id>.md — flat agent

Path `agents/<id>.md`. Required: `name` equals filename stem. Cursor
top-level: `name`, `description`, optional `model`, `readonly`,
`is_background`. Portability only under `metadata.opencode` /
`metadata.claude`. Body = second-person system prompt.

- `orchestrate` → `metadata.opencode.mode: primary`; others → `subagent`.
- Explore/export agents author `readonly: true` in the file (no adapter
  name-list).
- Optional top-level `model`; optional `metadata.opencode.variant`; else
  Nix `dotagents.models.*` + `cheapSubagents` inject at emit.

```markdown
---
name: github
description: >-
  Full GitHub development assistant — repos, PRs, issues, Actions.
  Write-capable.
readonly: false
metadata:
  opencode:
    mode: subagent
    temperature: 0.1
    permission:
      read: allow
      bash:
        "*": deny
        "gh *": allow
    tools:
      "github_*": true
  claude:
    tools: []
---

You are the github subagent. ...
```

**Cursor emit:** `name`, `description`, `model` (injected or file),
`readonly` — no `metadata`. **OpenCode/Claude emit:** hoist
`metadata.opencode` / `metadata.claude` + shared fields.

Never author OpenCode `mode` / `permission` / `tools` at the top level.
Never use `agents/<id>/agent.md` or sibling `config.json` as SoT.

### skills/<id>/SKILL.md — Cursor-pure skill

Path `skills/<id>/SKILL.md`; folder name = skill id (lowercase-hyphen).
Cursor Agent Skills frontmatter only (`name`, `description`, optional
`disable-model-invocation`, `argument-hint`, …). No `metadata.opencode` /
`metadata.claude` nests — skills stay Cursor-pure.

```markdown
---
name: code-review
description: >-
  Thorough code review for security, performance, and coverage gaps.
---

Review code changes for:
- Security vulnerabilities
- Performance implications
- Test coverage gaps
```

Slash-only (user-invoked) skills set `disable-model-invocation: true`.

### rules/<name>.mdc — Cursor rules

Path `rules/<name>.mdc`. Frontmatter uses Cursor rule fields (at minimum
`description`, `alwaysApply` as needed). Body = the shared instructions.
Cursor Adapter Emit passthrough-copies; OpenCode/Claude take body / tool-
native wrap from the Common Model.

```markdown
---
description: Be extremely concise in agent responses
alwaysApply: true
---

Be extremely concise. Sacrifice grammar for the sake of concision.
```

Do not use plain `agents.md` as the rules SoT.

### mcp.json — MCP Server Definitions

Plain JSON: `{ "mcpServers": { "<name>": { ... } } }`. Cursor shape only:

- stdio: `"type": "stdio"`, `command`, optional `args` / `env`
- remote: `url`, optional `headers` / `auth`

Authored values may use Cursor `${env:NAME}` placeholders. **MCP Instance**
Nix overlays secrets/enable/URL before emit. Do not put tool allowlists or
Nix-only `local`/`remote` naming in this file.

```json
{
  "mcpServers": {
    "nixos": {
      "type": "stdio",
      "command": "nixos-mcp",
      "args": []
    },
    "gitlab": {
      "url": "https://gitlab.com/api/v4/mcp"
    }
  }
}
```

## Authoring workflow

1. Pick the artifact: agent / skill / rule / MCP Server Definition.
2. Create the path from Canonical layout above (`agents/<id>.md` flat;
   `skills/<id>/SKILL.md`; `rules/<name>.mdc`; or edit `mcp.json`).
3. Write frontmatter in Cursor Authoring Format. Agents: nest OpenCode/Claude
   knobs under `metadata` only. Skills: Cursor-pure. Rules: `.mdc` fields.
   `mcp.json`: Cursor Server Definition shape, no frontmatter.
4. Write the body (agents: second-person system prompt).
5. Verify:

- Right path? Flat agent stem, skill folder = id, rules under `rules/`.
- `name` ≡ stem for agents?
- No OpenCode dialect at agent top level; no DotAgents protocol FM as SoT?
- Skills have no portability `metadata` nests?
- `mcp.json` is Cursor-shaped Server Definitions only?
- Nothing invented beyond ADR-0001 / this skill?

## Deploy note

This skill ships from `dmipeck/nix` `dotagents/skills/dotagents-files/`.
home-manager deploys it to Cursor / OpenCode / Claude skill locations.
New local agent/skill/rule: drop the file under `dotagents/` and run
`home-manager switch` — adapters pick it up. Per-user MCP enablement and
secrets are **MCP Instance** options in home-manager, not edits to the
authored Server Definition beyond `${env:…}` placeholders.
