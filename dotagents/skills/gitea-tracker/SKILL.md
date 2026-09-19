---
name: gitea-tracker
description: >-
  Preferred Gitea issue-tracker conventions for the engineering skills.
  Auto-discovered by /setup-matt-pocock-skills: when the git remote is a Gitea
  host (or the user picks Gitea), copy this skill's issue-tracker.md to
  docs/agents/issue-tracker.md. Also use when publishing specs/tickets to
  Gitea or running /wayfinder on a Gitea remote. MCP first; tea CLI fallback;
  blocking via native issue dependencies.
disable-model-invocation: true
---

# Gitea Tracker (preferred)

Canonical Gitea conventions for `/to-spec`, `/to-tickets`, `/wayfinder`, and
`/triage`. `/setup-matt-pocock-skills` auto-discovers this skill and, when
Gitea is the tracker, copies [issue-tracker.md](./issue-tracker.md) to
`docs/agents/issue-tracker.md` instead of freeform "Other" prose.

## Discovery contract

`/setup-matt-pocock-skills` treats this skill as installed when either:

- a `gitea-tracker` skill folder sits alongside `setup-matt-pocock-skills`,
  or
- `gitea-tracker` appears in the agent's available skills

When installed: infer the provider from `git remote -v` (and any configured
Gitea host from the environment / `tea` login — do not hardcode a hostname).
If the remote is Gitea, or the user picks Gitea, prefer this skill's
`issue-tracker.md`. Do not ask a separate conventions question — the preferred
shape is the default for every Gitea project.

## Type map

Gitea has Issues only (no GitLab-style Tasks).

| Artifact | Gitea type | Hierarchy |
|---|---|---|
| Spec (`/to-spec`) | **Issue** | parent |
| Wayfinder map (`/wayfinder`) | **Issue** (`wayfinder:map`) | parent |
| Ticket (`/to-tickets`) | **Issue** | child of parent spec |
| Wayfinder item | **Issue** (`wayfinder:<type>`) | child of map |

## Parent / child

Put `Part of #<n>` as the **first line** of the child Issue description.
Create the parent Issue first, then each child. Parent and child must be in
the same repository.

## Blocking relationships → native dependencies only

Use Gitea's **issue dependencies**. Same-repo only — refuse cross-repo deps.

When ticket `#10` is blocked by `#7`, make `#10` **depend on** `#7`:

`POST /repos/{owner}/{repo}/issues/10/dependencies` with body pointing at
issue `7`.

Do **not** use description footnotes, a `Blocked by:` body section, or the
`blocks` endpoint as the primary write (one edge via `dependencies` is
enough).

A ticket is unblocked when it has **no open dependencies**. Absence of
dependency rows means unblocked — no `[^blocked-by]` footnote.

## Tooling

Drive operations through the **Gitea MCP server** when available; fall back
to the [`tea`](https://gitea.com/gitea/tea) CLI only when an MCP tool is
missing or fails. MCP has no dependency tools today — use `tea api` for
create/list/remove dependency.

## After setup

Engineering skills read `docs/agents/issue-tracker.md`. Edit that file (or
re-run `/setup-matt-pocock-skills`) to change tracker behaviour; re-running
this skill alone is unnecessary.
