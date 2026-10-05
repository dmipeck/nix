---
name: gitea-tracker
description: >-
  Use when Gitea is selected as issue tracker during
  setup-matt-pocock-skills
disable-model-invocation: true
---

# Gitea Tracker (preferred)

Preferred Gitea conventions for `/to-spec`, `/to-tickets`, `/wayfinder`,
and `/triage`. This skill does **not** replace
`docs/agents/issue-tracker.md` wholesale. It supplies **additional
clauses** in [issue-tracker.md](./issue-tracker.md) that
`/setup-matt-pocock-skills` (and agents following it) merge onto a
Gitea-shaped base.

## Discovery contract

`/setup-matt-pocock-skills` treats this skill as installed when either:

- a `gitea-tracker` skill folder sits alongside `setup-matt-pocock-skills`,
  or
- `gitea-tracker` appears in the agent's available skills

When installed: infer the provider from `git remote -v` (and any
configured Gitea host from the environment / `tea` login — do not
hardcode a hostname). If the remote is Gitea, or the user picks Gitea,
apply this skill's additional clauses automatically. Do not ask a
separate conventions question.

## What setup must do

There is **no** upstream mattpocock Gitea template. When Gitea is
selected and this skill is installed:

1. **Seed** a Gitea-shaped base for `docs/agents/issue-tracker.md` when
   creating new: Conventions for create / read / list / comment /
   labels / close / PRs (MCP-first, `tea` fallback), plus the usual
   "PRs as a request surface" flag (default **no**). If the user
   arrived via freeform "Other", that prose may be the seed instead.
   If `docs/agents/issue-tracker.md` already exists, keep it as the
   base.
2. **Merge** the sections from this skill's
   [issue-tracker.md](./issue-tracker.md) onto that base. That file is
   **clause body only** — no apply/install preamble. Prefer those
   sections over conflicting seed text; leave non-conflicting seed
   sections intact. Do not copy any installation wording into the
   repo file.
3. **Do not** copy-replace the whole file with this skill's
   `issue-tracker.md`.

## Convention knowledge (encoded by the clauses)

Agents applying the clauses should know:

### Type map

Gitea has Issues only (no GitLab-style Tasks).

| Artifact | Gitea type | Hierarchy |
|---|---|---|
| Spec (`/to-spec`) | **Issue** | parent |
| Wayfinder map (`/wayfinder`) | **Issue** (`wayfinder:map`) | parent |
| Ticket (`/to-tickets`) | **Issue** | child of parent spec |
| Wayfinder item | **Issue** (`wayfinder:<type>`) | child of map |

### Parent / child

Put `Part of #<n>` as the **first line** of the child Issue
description. Create the parent first. Same repository only.

### Blocking → native dependencies only

Use Gitea's **issue dependencies** (same-repo only). No description
footnotes, no `Blocked by:` body section. A ticket is unblocked when
it has **no open dependencies**.

### Tooling

**Gitea MCP** first; [`tea`](https://gitea.com/gitea/tea) CLI fallback.
MCP has no dependency tools today — use `tea api` for
create/list/remove dependency.

## After setup

Engineering skills read `docs/agents/issue-tracker.md`. Edit that file
(or re-run `/setup-matt-pocock-skills`) to change tracker behaviour;
re-running this skill alone is unnecessary.
