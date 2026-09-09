# DotAgents

Neutral AI-agent content and the Nix machinery that ships it to tool
adapters (Claude, OpenCode).

## Language

**Skill**:
A package of agent instructions with layout
`$out/skills/<name>/SKILL.md` (or a collection bundle under
`$out/skills/`).
_Avoid_: plugin (tool-specific), prompt file

**Command**:
A slash-invoked instruction package whose store path *is* the markdown
file the agent runs.
_Avoid_: skill wrapper, skill stub, slash skill

**Skill-command**:
A Command derived from a Skill by hard-copying that skill's description
and body. Membership in `skillCommands` is the sole switch: hard-copy
the Command and have tool adapters omit that Skill.
`disable-model-invocation` is only a discovery signal for populating the
list.
_Avoid_: skill stub, Skill-tool proxy, skill wrapper

**Hard-copy**:
Build-time embedding of a Skill's `SKILL.md` description and body into a
Skill-command; no Skill-tool round-trip at runtime. Command frontmatter
keeps only `description:`; skill-only keys are dropped.
_Avoid_: symlink, reference, invoke-by-name

**Tool adapter**:
A home-manager module that maps neutral `dotagents.skills` /
`commands` / `agents` onto one product's config dialect (Claude and
OpenCode today). Adapters skip Skill names listed in `skillCommands`.
_Avoid_: skill→command adaptor (that is Skill-command generation, not a
tool adapter)
