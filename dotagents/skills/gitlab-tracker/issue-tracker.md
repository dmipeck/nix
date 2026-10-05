## Type map

| Artifact | GitLab type | How to create |
|---|---|---|
| Spec | **Issue** | `glab work-items create --type issue` |
| Wayfinder map | **Issue** | same + label `wayfinder:map` |
| Ticket | **Task** | `glab work-items create --type task`; set **parent** |
| Wayfinder item | **Task** | same; set **parent** |

Also use `glab issue create` when `glab work-items` is unavailable.
Prefer `glab work-items` for typed work items.

## Parent / child (hierarchy, not `Part of #n`)

- Set the Task's **parent** to the owning Issue (GitLab Child items /
  hierarchy). Do **not** use `Part of #<n>` as the hierarchy signal.
- If `glab` has no `--parent` flag, set parent via GraphQL
  `hierarchyWidget.parentId` (parent = the Issue's work-item GID).
- Task and parent must be in the same project.

## When a skill says "publish to the issue tracker"

- **Spec** / wayfinder map → GitLab **Issue**.
- **Ticket** / wayfinder item → GitLab **Task**, child of the parent
  Issue (create the parent first if needed). Apply `ready-for-agent`
  unless instructed otherwise.
- Do **not** publish tickets as Issues or specs as Tasks.

## When a skill says "fetch the relevant ticket"

Open the Task (or Issue) by IID; read description, footnotes, and
notes.

## Blocking relationships (footnotes only)

GitLab has no Free-tier-portable native `blocked-by`. **Never** use:

- `/blocked_by` quick actions
- blocking issue links (`blocks` / `is_blocked_by`)
- a `Blocked by:` body section

Put blocking edges in a description footnote on the Task:

```markdown
[^blocked-by]: #12, #15
```

No blockers:

```markdown
[^blocked-by]: none
```

A Task is unblocked when every referenced IID is closed, or the
footnote is `none`. Parse only `[^blocked-by]`.

## Wayfinding operations

- **Map**: one **Issue** labelled `wayfinder:map`, holding Destination /
  Notes / Decisions-so-far / Fog. Prefer
  `glab work-items create --type issue`, then label `wayfinder:map`.
- **Child ticket**: a **Task** that is a **child** of the map Issue
  (hierarchy parent — not `Part of #<map>`). Labels:
  `wayfinder:<type>` (`research` / `prototype` / `grilling` / `task`).
  Blocking via `[^blocked-by]` footnote only. Once claimed, assign the
  Task to the driving dev.
- **Frontier query**: list open child Tasks of the map Issue; drop any
  whose `[^blocked-by]` cites a still-open IID, or that already has an
  assignee; first in map/hierarchy order wins.
- **Claim**: assign the Task to `@me` — the session's first write.
- **Resolve**: note the answer on the Task, close it, then append a
  context pointer (gist + link) to the map Issue's Decisions-so-far.
