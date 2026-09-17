---
name: gitlab-tracker
description: "Preferred GitLab issue-tracker conventions for the engineering skills: specs and wayfinder maps as Issues, tickets and wayfinder items as child Tasks, blocking edges as description footnotes (no native blocked-by). Use whenever configuring a GitLab repo with /setup-matt-pocock-skills, publishing specs/tickets to GitLab, or running /wayfinder on a GitLab remote."
disable-model-invocation: true
---

# GitLab Tracker (preferred)

Canonical GitLab conventions for `/to-spec`, `/to-tickets`, `/wayfinder`, and `/triage`. `/setup-matt-pocock-skills` auto-discovers this skill and, when GitLab is chosen, copies [issue-tracker.md](./issue-tracker.md) to `docs/agents/issue-tracker.md` instead of the bundled generic GitLab template.

## Discovery contract

`/setup-matt-pocock-skills` treats this skill as installed when either:

- a `gitlab-tracker` skill folder sits alongside `setup-matt-pocock-skills`, or
- `gitlab-tracker` appears in the agent's available skills

When installed and the user picks GitLab, prefer this skill's `issue-tracker.md`. Do not ask a separate question — the preferred shape is the default for every GitLab project.

## Type map

| Artifact | GitLab work-item type | Hierarchy |
|---|---|---|
| Spec (`/to-spec`) | **Issue** | parent |
| Wayfinder map (`/wayfinder`) | **Issue** (label `wayfinder:map`) | parent |
| Ticket (`/to-tickets`) | **Task** | child of its parent spec Issue |
| Wayfinder item | **Task** (label `wayfinder:<type>`) | child of its map Issue |

Never publish tickets or wayfinder items as Issues. Never publish specs or maps as Tasks.

## Parent / child

Always set the Task's **parent** to the owning Issue (GitLab hierarchy / Child items). Create the parent Issue first, then create each Task as a child of that Issue.

Prefer `glab work-items create --type …` when available. To nest a Task under an Issue, set the hierarchy parent (GraphQL `hierarchyWidget.parentId` if `glab` has no `--parent` flag yet). Tasks and their parent Issue must share the same project.

## Blocking relationships → footnotes only

GitLab has no portable Free-tier `blocked-by` that every clone can rely on. **Do not** use:

- `/blocked_by` quick actions
- issue link types (`blocks` / `is_blocked_by` / `relates_to`) for blocking
- a `Blocked by:` body section

Record every blocking edge as a **markdown footnote** at the bottom of the Task description:

```markdown
[^blocked-by]: #12, #15
```

No blockers:

```markdown
[^blocked-by]: none
```

A Task is unblocked when every `#n` in `[^blocked-by]` is closed (or the footnote is `none`). Parse only that footnote name; ignore other footnotes.

## After setup

Engineering skills read `docs/agents/issue-tracker.md`. Edit that file (or re-run `/setup-matt-pocock-skills`) to change tracker behaviour; re-running this skill alone is unnecessary.
