---
name: gitlab-tracker
description: >-
  Use when GitLab is selected as issue tracker during
  setup-matt-pocock-skills
disable-model-invocation: true
---

# GitLab Tracker (preferred)

Preferred GitLab conventions for `/to-spec`, `/to-tickets`, `/wayfinder`,
and `/triage`. This skill does **not** replace
`docs/agents/issue-tracker.md` wholesale. It supplies **additional
clauses** in [issue-tracker.md](./issue-tracker.md) that
`/setup-matt-pocock-skills` (and agents following it) merge onto the
seeded or existing template.

## Discovery contract

`/setup-matt-pocock-skills` treats this skill as installed when either:

- a `gitlab-tracker` skill folder sits alongside `setup-matt-pocock-skills`,
  or
- `gitlab-tracker` appears in the agent's available skills

When installed and the user picks GitLab, apply this skill's additional
clauses automatically. Do not ask a separate conventions question.

## What setup must do

When GitLab is selected and this skill is installed:

1. **Seed** `docs/agents/issue-tracker.md` from the setup skill's
   bundled `issue-tracker-gitlab.md` when creating new. If
   `docs/agents/issue-tracker.md` already exists, keep it as the base —
   do not overwrite with a blank slate.
2. **Merge** the sections from this skill's
   [issue-tracker.md](./issue-tracker.md) onto that base. That file is
   **clause body only** — no apply/install preamble. Prefer those
   sections over conflicting seed text; leave non-conflicting seed
   sections intact. Do not copy any installation wording into the
   repo file.
3. **Do not** copy-replace the whole file with this skill's
   `issue-tracker.md` (or any other full preferred template).

## Convention knowledge (encoded by the clauses)

Agents applying the clauses should know:

### Type map

| Artifact | GitLab work-item type | Hierarchy |
|---|---|---|
| Spec (`/to-spec`) | **Issue** | parent |
| Wayfinder map (`/wayfinder`) | **Issue** (`wayfinder:map`) | parent |
| Ticket (`/to-tickets`) | **Task** | child of parent spec Issue |
| Wayfinder item | **Task** (`wayfinder:<type>`) | child of map Issue |

Never publish tickets or wayfinder items as Issues. Never publish specs
or maps as Tasks.

### Parent / child

Always set the Task's **parent** to the owning Issue (GitLab hierarchy /
Child items). Do **not** use `Part of #n` as the hierarchy signal.
Create the parent Issue first, then each Task as a child. Prefer
`glab work-items create --type …` when available.

### Blocking → footnotes only

**Do not** use `/blocked_by`, blocking issue links, or a `Blocked by:`
body section. Record every blocking edge as:

```markdown
[^blocked-by]: #12, #15
```

No blockers: `[^blocked-by]: none`. A Task is unblocked when every `#n`
is closed (or the footnote is `none`). Parse only that footnote name.

## After setup

Engineering skills read `docs/agents/issue-tracker.md`. Edit that file
(or re-run `/setup-matt-pocock-skills`) to change tracker behaviour;
re-running this skill alone is unnecessary.
