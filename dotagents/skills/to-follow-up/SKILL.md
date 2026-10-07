---
name: to-follow-up
description: >-
  Park decided-but-out-of-scope work as tickets on the project issue tracker so
  it isn't lost when the current effort closes.
disable-model-invocation: true
---

# To Follow-Up

Capture work that **has already been decided needs doing**, but is **out of
scope** for the current effort, and publish it as tickets on the configured
tracker.

This is a parking lot, not a plan. Do **not** invent new work, re-interview for
ideas, or re-slice in-scope work into tracer bullets — that is `/to-tickets`.
Do **not** file "won't do" items; those are scope cuts, not follow-ups.

The issue tracker and triage label vocabulary should have been provided to
you. If `docs/agents/issue-tracker.md` is missing, tell the user to run
`/setup-matt-pocock-skills`. Read that file (and
`docs/agents/triage-labels.md` when present) for how to publish.

## Process

### 1. Gather candidates

Work from whatever is already known. Sources, in priority order:

1. Items the user named when invoking this skill (titles, bullets, issue refs).
2. An **Out of Scope** section on a spec, map, or issue the user pointed at —
   fetch via `docs/agents/issue-tracker.md` when the source is a ticket.
3. Decisions in the current conversation that were explicitly deferred
   ("later", "not this PR", "out of scope for this", "follow up").

For each candidate, keep only items that pass **both**:

- **Decided**: someone already committed that this should happen (not a vague
  idea or open question).
- **Deferred, not discarded**: ruled out of *this* effort, not ruled out
  forever. Forever-cuts stay untracked (or get `wontfix` only if the user
  asks).

Drop anything still fuzzy, speculative, or already tracked. If a candidate
already has a ticket, note the link and skip creating a duplicate.

### 2. Quiz the user

Present the proposed follow-ups as a numbered list. For each item, show:

- **Title**: short descriptive name
- **Why deferred**: one line on why it sits outside the current effort
- **What was decided**: the commitment to preserve, from the user's
  perspective
- **Parent**: the current spec / issue / PR / conversation thread to link, if
  any

Ask:

- Drop any that should stay untracked (true won't-do, or too vague)?
- Merge or split any?
- Is any item already fully agent-ready, or should they all land as triage
  fodder?

Iterate until the user approves the list. Do not publish before approval.

### 3. Publish

Publish one ticket per approved item, using the workflow in
`docs/agents/issue-tracker.md`:

- **Local files** → one file per ticket under
  `.scratch/follow-ups/<slug>/issues/<NN>-<slug>.md` (or under the current
  feature's `.scratch/<feature>/issues/` if the user is mid-feature and
  prefers them co-located). Number from `01`.
- **A real issue tracker** → one issue per ticket. Link the parent when the
  platform supports it (comment, task-list line, or sub-issue); otherwise put
  **Parent** in the body.

**Labels:** default to the `needs-triage` role from
`docs/agents/triage-labels.md`. These are parking-lot tickets, not
agent-grabbable by construction. Apply `ready-for-agent` only when the user
confirmed an item is already fully specified (acceptance criteria clear, no
open product questions). Never invent a new label.

Use the template below. Avoid stale file paths and code snippets unless a
prototype already encoded a decision more precisely than prose can — then trim
to the decision-rich bits and note the prototype origin.

<follow-up-template>

## Parent

A reference to the effort this was deferred from (spec issue, PR, map, or
"conversation"), or omit if none.

## Why deferred

One or two sentences: why this sits outside the current effort.

## What was decided

The commitment to preserve — what should exist when this is eventually done,
from the user's perspective. Not a layer-by-layer implementation plan.

## Acceptance criteria

- [ ] Criterion 1 (include only what is already agreed; leave a short "needs
      sharpening" note if criteria are not ready yet)

## Context

Any non-obvious constraints, links, or decisions that a future session would
otherwise lose. Keep short.

</follow-up-template>

### 4. Report

List every created ticket (identifier + title + label applied). Mention any
candidates skipped as duplicates or won't-dos. Stop. Do not start implementing
them.
