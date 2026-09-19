# Issue tracker: Gitea (preferred)

Issues, specs, tickets, and wayfinder artifacts for this repo live in Gitea.
Drive operations through the **Gitea MCP server** when available; fall back
to the [`tea`](https://gitea.com/gitea/tea) CLI only when an MCP tool is
missing or fails. The `tea` commands below document the operations the MCP
server (or `tea api`) performs.

## Type map

| Artifact | Gitea type | How to create |
|---|---|---|
| Spec | **Issue** | MCP `issue_write` / `tea issues create` |
| Wayfinder map | **Issue** | same + label `wayfinder:map` |
| Ticket | **Issue** | same; first line `Part of #<parent>` |
| Wayfinder item | **Issue** | same; `Part of #<map>` + `wayfinder:<type>` |

## Conventions

- **Create**: MCP `issue_write` (create). Fallback:
  `tea issues create --title "..." --body "..."`. Heredoc or `--body -` for
  multi-line bodies. First line of a child body must be `Part of #<n>`.
- **Read**: MCP `issue_read`. Fallback: `tea issues view <index>`.
- **List**: MCP `list_issues` / `search_issues`. Fallback:
  `tea issues list` (JSON when available).
- **Comment**: MCP issue comment via `issue_write` when supported; else
  `tea api` on the issue comments endpoint.
- **Labels**: MCP `label_write` / issue update. Fallback:
  `tea issues edit <index> --labels "..."`.
- **Close**: MCP `issue_write` (state closed). Fallback:
  `tea issues close <index>` (comment first if needed).
- **Pull requests**: MCP `pull_request_*` tools; fallback `tea pulls …`.
  Issues and PRs have separate number spaces; `#42` is unambiguous once you
  know the surface.

Infer owner/repo from `git remote -v`; `tea` does this inside a clone when
configured.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external
pull requests as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as Issues, using
the MCP / `tea pulls` equivalents for read, list, comment, label, and close.

## When a skill says "publish to the issue tracker"

- **Spec** → create a Gitea **Issue**.
- **Ticket** → create a Gitea **Issue** whose description starts with
  `Part of #<parent-spec>`. Apply the `ready-for-agent` triage label unless
  instructed otherwise.
- Do **not** invent a separate work-item type — everything is an Issue.

## When a skill says "fetch the relevant ticket"

Open the Issue by index and read its description, labels, comments, and
dependency list.

## Blocking relationships (native dependencies only)

Same-repo only. When `#10` is blocked by `#7`, make `#10` depend on `#7`:

```bash
tea api -X POST -d '{"index":7}' repos/{owner}/{repo}/issues/10/dependencies
```

List blockers (issues that block this one):

```bash
tea api repos/{owner}/{repo}/issues/10/dependencies
```

Remove a dependency with `DELETE` on the same path and an IssueMeta body.

Prefer MCP if a dependency tool appears later; until then **always** use
`tea api` for dependency edges (do not skip to body footnotes).

A ticket is unblocked when `GET …/dependencies` returns no **open** issues.
No `[^blocked-by]` footnotes. No `Blocked by:` body section.

## Wayfinding operations

Used by `/wayfinder`.

- **Map**: one **Issue** labelled `wayfinder:map`, holding Destination /
  Notes / Decisions-so-far / Fog.
- **Child ticket**: an **Issue** with first line `Part of #<map>` and labels
  `wayfinder:<type>` (`research` / `prototype` / `grilling` / `task`).
  Blocking via native dependencies only. Once claimed, assign the Issue to
  the driving dev.
- **Frontier query**: list open Issues whose body starts with
  `Part of #<map>`; drop any with an open dependency or an assignee; first
  in map order wins.
- **Claim**: assign the Issue to `@me` — the session's first write.
- **Resolve**: comment the answer, close the Issue, then append a context
  pointer (gist + link) to the map Issue's Decisions-so-far.
