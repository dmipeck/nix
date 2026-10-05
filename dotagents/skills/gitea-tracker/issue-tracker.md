## Type map

| Artifact | Gitea type | How to create |
|---|---|---|
| Spec | **Issue** | MCP `issue_write` / `tea issues create` |
| Wayfinder map | **Issue** | same + label `wayfinder:map` |
| Ticket | **Issue** | same; first line `Part of #<parent>` |
| Wayfinder item | **Issue** | same; `Part of #<map>` + `wayfinder:<type>` |

Everything is an Issue — do not invent a separate work-item type.

## Parent / child (`Part of #n`)

- First line of a child Issue body must be `Part of #<n>`.
- Create the parent Issue first, then each child.
- Parent and child must be in the same repository.

## Tooling

Drive operations through the **Gitea MCP server** when available; fall
back to [`tea`](https://gitea.com/gitea/tea) only when an MCP tool is
missing or fails. Prefer MCP for create / read / list / comment /
labels / close / PRs; use `tea api` for dependency edges until MCP
gains dependency tools.

## When a skill says "publish to the issue tracker"

- **Spec** / wayfinder map → Gitea **Issue**.
- **Ticket** / wayfinder item → Gitea **Issue** whose description
  starts with `Part of #<parent>`. Apply `ready-for-agent` unless
  instructed otherwise.

## When a skill says "fetch the relevant ticket"

Open the Issue by index; read description, labels, comments, and
dependency list.

## Blocking relationships (native dependencies only)

Same-repo only. When `#10` is blocked by `#7`, make `#10` depend on
`#7`:

```bash
tea api -X POST -d '{"index":7}' \
  repos/{owner}/{repo}/issues/10/dependencies
```

List blockers:

```bash
tea api repos/{owner}/{repo}/issues/10/dependencies
```

Remove with `DELETE` on the same path and an IssueMeta body.

**Do not** use `[^blocked-by]` footnotes or a `Blocked by:` body
section. A ticket is unblocked when `GET …/dependencies` returns no
**open** issues. Refuse cross-repo deps.

## Wayfinding operations

- **Map**: one **Issue** labelled `wayfinder:map`, holding Destination /
  Notes / Decisions-so-far / Fog.
- **Child ticket**: an **Issue** with first line `Part of #<map>` and
  labels `wayfinder:<type>` (`research` / `prototype` / `grilling` /
  `task`). Blocking via native dependencies only. Once claimed, assign
  the Issue to the driving dev.
- **Frontier query**: list open Issues whose body starts with
  `Part of #<map>`; drop any with an open dependency or an assignee;
  first in map order wins.
- **Claim**: assign the Issue to `@me` — the session's first write.
- **Resolve**: comment the answer, close the Issue, then append a
  context pointer (gist + link) to the map Issue's Decisions-so-far.
