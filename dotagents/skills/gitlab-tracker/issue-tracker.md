# Issue tracker: GitLab (preferred)

Issues, specs, tickets, and wayfinder artifacts for this repo live in GitLab. Use the [`glab`](https://gitlab.com/gitlab-org/cli) CLI for all operations. Prefer `glab work-items` when creating typed work items.

## Type map

| Artifact | GitLab type | How to create |
|---|---|---|
| Spec | **Issue** | `glab work-items create --type issue` (or `glab issue create`) |
| Wayfinder map | **Issue** | `glab work-items create --type issue` + label `wayfinder:map` |
| Ticket / wayfinder item | **Task** | `glab work-items create --type task`, then set **parent** to the owning Issue |

## Conventions

- **Create an Issue** (spec / map): `glab work-items create --type issue --title "..." --description "..."`. Heredoc or `--description -` for multi-line bodies. Labels: `glab issue update <iid> --label "..."`.
- **Create a Task** (ticket / wayfinder item): `glab work-items create --type task --title "..." --description "..."`, then attach it as a **child** of the parent Issue (GitLab Child items / hierarchy). If `glab` has no `--parent` flag, set the parent via GraphQL `workItemCreate` / `workItemUpdate` `hierarchyWidget.parentId` (parent = the Issue's work-item GID). Task and parent must be in the same project.
- **Read**: `glab issue view <iid> --comments` for Issues; for Tasks use `glab work-items view` when available, otherwise `glab api` / GraphQL on the work item. Use `-F json` for machine-readable output.
- **List**: `glab issue list -F json` with `--label` filters for Issues. For Tasks under a parent, list the Issue's child items (UI Child items / GraphQL hierarchy), not a flat Issue list.
- **Comment**: `glab issue note <iid> --message "..."` (GitLab calls comments "notes"). Same note flow for Tasks via work-item notes when `glab issue note` does not apply.
- **Labels**: `glab issue update <iid> --label "..."` / `--unlabel "..."`.
- **Close**: `glab issue close <iid>` (post the explanation with `glab issue note` first — `close` takes no message). Close Tasks the same way via their IID / work-item close.
- **Merge requests**: `glab mr create`, `glab mr view`, `glab mr note`, etc. Issues and MRs have separate number spaces; `#42` is unambiguous once you know the surface.

Infer the repo from `git remote -v`; `glab` does this automatically inside a clone.

## Merge requests as a triage surface

**MRs as a request surface: no.** _(Set to `yes` if this repo treats external merge requests as feature requests; `/triage` reads this flag.)_

When set to `yes`, MRs run through the same labels and states as Issues, using the `glab mr` equivalents:

- **Read an MR**: `glab mr view <number> --comments` and `glab mr diff <number>`.
- **List external MRs for triage**: `glab mr list -F json`, keep only MRs whose author is not a project member/owner.
- **Comment / label / close**: `glab mr note`, `glab mr update --label`/`--unlabel`, `glab mr close`.

## When a skill says "publish to the issue tracker"

- **Spec** → create a GitLab **Issue**.
- **Ticket** → create a GitLab **Task** that is a **child** of the parent spec Issue (create the parent first if needed). Apply the `ready-for-agent` triage label unless instructed otherwise.
- Do **not** publish tickets as Issues or specs as Tasks.

## When a skill says "fetch the relevant ticket"

Open the Task (or Issue) by IID and read its description, footnotes, and notes/comments.

## Blocking relationships (footnotes only)

GitLab has no Free-tier-portable native `blocked-by`. **Never** use `/blocked_by`, blocking issue links, or a `Blocked by:` section.

Put blocking edges in a description footnote on the Task:

```markdown
[^blocked-by]: #12, #15
```

No blockers:

```markdown
[^blocked-by]: none
```

A Task is unblocked when every referenced IID is closed, or the footnote is `none`. Parse only `[^blocked-by]`.

## Wayfinding operations

Used by `/wayfinder`.

- **Map**: one **Issue** labelled `wayfinder:map`, holding Destination / Notes / Decisions-so-far / Fog. `glab work-items create --type issue`, then label `wayfinder:map`.
- **Child ticket**: a **Task** that is a child of the map Issue. Labels: `wayfinder:<type>` (`research` / `prototype` / `grilling` / `task`). Blocking via `[^blocked-by]` footnote only. Once claimed, assign the Task to the driving dev.
- **Frontier query**: list open child Tasks of the map Issue; drop any whose `[^blocked-by]` cites an still-open IID, or that already has an assignee; first in map/hierarchy order wins.
- **Claim**: assign the Task to `@me` — the session's first write.
- **Resolve**: note the answer on the Task, close it, then append a context pointer (gist + link) to the map Issue's Decisions-so-far.
