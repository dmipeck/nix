---
name: commit
description: >-
  Delegate every commit to the commit subagent. Use before any commit —
  when the user says "commit this", when staging changes, or when a commit
  message needs writing. The commit subagent reviews pending changes, decides
  boundaries, writes conventional + caveman-compressed messages, runs the
  commit, and reports hook failures without taking action.
---

# Commit

Every commit goes through the `commit` subagent. Do not write commit
messages or run `git commit` in the main thread.

## When

- Before every commit.
- User asks to commit, stage, or write a commit message.
- A pre-commit / commit-msg hook failed and a retry is considered.

## How

1. Invoke the `commit` subagent (Task tool) with the worktree context. It
  inspects `git status` / `git diff` itself.
2. The commit subagent picks commit boundaries (one self-contained change per
  commit; refactor separate from behavior), writes conventional +
  caveman-commit messages, stages, and commits.
3. If it reports a hook failure, relay the report to the user. Do not retry,
  amend, or bypass hooks yourself.

## Model

Run the commit subagent on the cheapest model that fits. Conventional,
caveman-compressed messages are small and mechanical — a cheap model with low
reasoning/effort writes them fine. Before invoking, check for free opencode
model access (`/models`, `opencode models`) and prefer a free model. Escalate
only for messy changes where commit boundaries or message wording are genuinely
hard to judge.

## Follow

- `git-workflow` for boundaries, worktree, and PR flow.
- `conventional-commits` + `caveman-commit` for message format (the commit
  subagent applies these).
- `thrifty` for cheap-model + low-effort selection.
