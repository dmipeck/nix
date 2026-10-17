---
name: worktree
description: >-
  Create an isolated Cursor git worktree, run worktrees.json setup, and keep
  all task work on WORKTREE_PATH. Use when starting isolated git work, when
  the user asks for a worktree, or when another skill needs WORKTREE_PATH
  before edits.
---

# Worktree

1. Run the Cursor `/worktree` create block for this OS (optional
   `WORKTREE_START_REF` if the user passed a ref). Do not hand-roll a
   different layout.
2. Immediately after `git worktree add`, discover and run setup from
   `.cursor/worktrees.json` in `REPO_ROOT` then `WORKTREE_PATH` (prefer
   `WORKTREE_PATH` when it defines setup keys). Skip only when neither
   file has applicable setup for this OS.
3. Keep the chat mapping: workspace folder → `REPO_ROOT` →
   `WORKTREE_PATH`. All later reads, edits, shell, and repo-local git for
   this task use `WORKTREE_PATH` only.
4. Report `WORKTREE_ID`, `WORKTREE_PATH`, `REPO_ROOT`, `HEAD_COMMIT`,
   `WORKTREE_START_REF`, and whether setup ran, was skipped after checking
   both paths, or failed. Merge-back `/apply-worktree`; cleanup
   `/delete-worktree`.
