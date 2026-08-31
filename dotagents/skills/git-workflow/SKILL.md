---
name: git-workflow
description: >-
    Git workflow and commit structure rules. Use before banching, commiting, or
    pushing
---

# Git Workflow

Checklist: change "about to start" to "merged", in order.

## 1. Before starting work

- Pull latest from default branch. Fast-forward (or rebase) — no stale base.
- Not on a worktree yet → create one. Don't work on the default branch checkout.
- Worktrees must live in `.agent/worktrees/` in the repo root.
- Create with `git worktree add .agent/worktrees/<change-name> <branch>`.
- `.agent/worktrees/` → `.git/info/exclude` so it never shows in `git status`.
- Open the PR/MR early — draft, as soon as the first commit is ready to push.
- Don't wait for "done". Reviewers and CI see progress live.

## 2. While working

- Follow the `conventional-commits` skill for message format and type
  (`skill: conventional-commits`). Type matches what commit does, not task.
- Commit and push after each discrete change, not only at the end.
- Each self-contained edit is its own commit.
- Keep commits small, one thing each. Message needing "and" is two commits.
- Fix/feature needs a refactor first → separate `refactor:` commit before it.
- Never bundle refactor with behavior change, or add it after as cleanup.

## 3. Before every commit

- Repo must build and pass tests at that commit, not just at branch tip.
- Bisecting must never land on a broken intermediate state.
- Change can't build or pass on its own → not a valid commit boundary.
- Slice smaller or fold until it is.
