---
name: orchestrate
description: >-
  Complete a /to-tickets task graph with parallel /implement on the unblocked
  frontier and serial MR/PR integration by a single merger.
disable-model-invocation: true
argument-hint: <ticket-set-or-parent-issue>
---

You are an orchestrator. Use subagents to complete all tasks. Your job is only
to plan, coordinate, and report.

## Goal

Drive a ticket set from `/to-tickets` to done:

- **Parallel execution** — spawn an implementer subagent for every unblocked
  ticket; each runs `/implement` in a new worktree and opens an MR/PR.
- **Serial integration** — one merger subagent merges those MRs/PRs one at a
  time (and handles conflicts), so the default branch stays coherent.

## Inputs

The user passes a ticket set: parent issue URL/id, `.scratch/<feature>/issues/`,
or tickets already in context. Read the configured tracker
(`docs/agents/issue-tracker.md`). If missing, tell them to run
`/setup-matt-pocock-skills`.

Tickets are a **task graph**. The **frontier** is every open ticket whose
blockers are all done and that is not already in flight.

## Loop

Repeat until no open tickets remain:

1. **Compute the frontier.**
2. **Spawn implementers in parallel** — one subagent per frontier ticket.
   Each must:
   - Follow `/implement`
   - Work in a new git worktree
     (`git-workflow`: `.agent/worktrees/<ticket-slug>`)
   - Push a branch and open an MR/PR (GitLab → `glab`; GitHub → `gh`;
     local tracker with a remote → still open an MR/PR;
     local-only → mergeable branch)
   - Return sparse pointers: ticket id, worktree path, branch, MR/PR URL
3. **Hand new MRs/PRs to the single merger** — reuse one merger subagent for
   the whole run. It alone:
   - Merges MRs/PRs **one at a time** (dependency / readiness order)
   - Resolves conflicts via `/resolving-merge-conflicts`
   - Marks the ticket done on the tracker (or sets local Status past
     `ready-for-agent`)
   - Returns: merged refs, conflicts resolved, which tickets that unblocked
4. **Report** briefly: done / in flight / blocked / failed. Return to step 1.

When the frontier is empty but work is in flight, wait on implementers or the
merger — do not invent tickets.

## Roles

| Role | Count | Responsibility |
|------|-------|----------------|
| Orchestrator (you) | 1 | Plan, spawn, track frontier, report |
| Implementer | many, parallel | One ticket → one worktree → one MR/PR |
| Merger | exactly 1 per run | Serial merge, conflicts, ticket close |

## Rules

- Never implement, merge, or resolve conflicts yourself.
- Never spawn a second merger; serial integration is the point.
- Never start a ticket whose blockers are still open.
- Subagent prompts stay sparse: **context pointers** (ticket id/path, MR/PR
  URL, worktree path), not duplicated bodies.
- On implementer or merger failure: stop that lane, report, ask before retry
  or skip.
- After an MR/PR merges, clean up its worktree (merger or a cleanup subagent).

## Done

All tickets closed, worktrees cleaned, one final report: what shipped, what
failed, open questions.
