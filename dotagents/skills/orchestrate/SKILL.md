---
name: orchestrate
description: >-
  Complete a /to-tickets task graph with parallel /implement on the unblocked
  frontier, serial MR/PR merges into one composite branch/PR, and a human
  review gate before that composite lands on the default branch.
disable-model-invocation: true
argument-hint: <ticket-set-or-parent-issue>
---

You are an orchestrator. Use subagents to complete all tasks. Your job is only
to plan, coordinate, and report.

## Goal

Drive a ticket set from `/to-tickets` to a **composite MR/PR ready for human
review**:

- **Composite branch** — one integration branch + MR/PR targeting the default
  branch; all ticket MRs/PRs merge into it, not into default.
- **Parallel execution** — spawn an implementer subagent for every unblocked
  ticket; each runs `/implement` in a new worktree and opens an MR/PR
  **against the composite branch**.
- **Serial integration** — one merger subagent merges those MRs/PRs one at a
  time into the composite (and handles conflicts).
- **Human gate** — never merge the composite into default; wait for a human
  to review and merge it.

## Inputs

The user passes a ticket set: parent issue URL/id, `.scratch/<feature>/issues/`,
or tickets already in context. Read the configured tracker
(`docs/agents/issue-tracker.md`). If missing, tell them to run
`/setup-matt-pocock-skills`.

Tickets are a **task graph**. The **frontier** is every open ticket whose
blockers are all done and that is not already in flight.

## Setup (once)

Before the loop, spawn a subagent (reuse the merger if already spawned) to:

1. Name the composite branch from the ticket set / parent issue
   (e.g. `orchestrate/<feature-slug>`).
2. Branch from the current default tip; push it.
3. Open a draft MR/PR **targeting default** (GitLab → `glab`; GitHub → `gh`;
   local-only → note the branch for later).
4. Return sparse pointers: composite branch, composite MR/PR URL.

Hold those pointers for every later spawn. Do not start implementers until
the composite exists.

## Loop

Repeat until no open tickets remain:

1. **Compute the frontier.**
2. **Spawn implementers in parallel** — one subagent per frontier ticket.
   Each must:
   - Follow `/implement`
   - Work in a new git worktree
     (`git-workflow`: `.agent/worktrees/<ticket-slug>`)
   - Base the ticket branch on the **composite** branch (not default)
   - Push and open an MR/PR **targeting the composite branch**
     (GitLab → `glab`; GitHub → `gh`;
     local tracker with a remote → still open an MR/PR;
     local-only → mergeable branch into composite)
   - Return sparse pointers: ticket id, worktree path, branch, MR/PR URL
3. **Hand new MRs/PRs to the single merger** — reuse one merger subagent for
   the whole run. It alone:
   - Merges MRs/PRs **into the composite branch**, one at a time
     (dependency / readiness order)
   - Resolves conflicts via `/resolving-merge-conflicts`
   - Marks the ticket done on the tracker (or sets local Status past
     `ready-for-agent`)
   - Returns: merged refs, conflicts resolved, which tickets that unblocked
4. **Report** briefly: done / in flight / blocked / failed. Return to step 1.

When the frontier is empty but work is in flight, wait on implementers or the
merger — do not invent tickets.

## After the loop

When every ticket is merged into the composite:

1. Mark the composite MR/PR ready for review (undraft if it was draft).
2. Wait until CI on that MR/PR is green (spawn a subagent to poll checks;
   on failure, hand off to the merger to fix or report — do not merge to
   default either way).
3. **Stop.** Do not merge composite → default. Do not ask a subagent to.
4. Report the composite MR/PR URL and wait for a human to review and merge.

## Roles

| Role | Count | Responsibility |
|------|-------|----------------|
| Orchestrator (you) | 1 | Plan, spawn, track frontier, report |
| Implementer | many, parallel | Ticket → worktree → MR/PR → composite |
| Merger | exactly 1 per run | Composite setup; serial merge; close |

## Rules

- Never implement, merge, or resolve conflicts yourself.
- Never spawn a second merger; serial integration is the point.
- Never merge the composite MR/PR into the default branch — human only.
- Never start a ticket whose blockers are still open.
- Ticket MRs/PRs always target the composite branch, never default.
- Subagent prompts stay sparse: **context pointers** (ticket id/path, MR/PR
  URL, worktree path, composite branch/URL), not duplicated bodies.
- On implementer or merger failure: stop that lane, report, ask before retry
  or skip.
- After a ticket MR/PR merges into composite, delete its remote branch and
  clean up its worktree (merger or a cleanup subagent).

## Done

All of:

- Every targeted work-item's MR/PR is merged into the composite branch
- Remote branches for those merged ticket MRs/PRs are deleted
- Worktrees for those ticket branches are cleaned up
- A composite MR/PR targeting default exists and contains those merges
- CI on the composite MR/PR is passing
- Composite MR/PR is ready for human review (not merged to default)

Final report: composite URL, ticket MRs/PRs folded in, CI status, what
failed, open questions. Default-branch merge is out of scope for this run.
