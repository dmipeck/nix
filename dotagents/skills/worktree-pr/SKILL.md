---
name: worktree-pr
description: >-
  Start task work in an isolated git worktree with a draft MR/PR open before
  real edits, then finish only after CI is green and the MR/PR is undrafted.
  Use when the user invokes /worktree-pr or asks to work in a worktree with a
  draft PR/MR and CI gate.
disable-model-invocation: true
---

# Worktree + draft MR/PR

Slash-only workflow: isolated worktree, early draft MR/PR, CI green, then
ready.

## 1. Worktree first

Call the Skill tool with `worktree`. Complete create + setup before any
task edits. Record `WORKTREE_PATH`. All later reads, edits, shell, and
repo-local git for this task use that path only.

## 2. Draft MR/PR before starting work

A draft MR/PR must exist before task work begins. Host timing differs:

- **GitLab** — Create the draft MR **before any commits**. Push the branch
  at the default-branch tip (no unique commits yet), open draft MR
  (`glab`), then start committing.
- **GitHub** — Needs a commit to open a PR. Defer the draft PR until the
  **first commit** is pushable, then push and open draft immediately
  (`gh`). Do not start further task work until that draft PR exists.

Detect host from `git remote` (`gitlab.com` / `github.com` or `glab` /
`gh` defaults). Title: conventional-commits. Do not merge unless asked.

## 3. While working

- Commit and push discrete changes from `WORKTREE_PATH`.
- Keep the MR/PR draft until the done gate below.
- Never treat the task as finished while the branch is dirty, unpushed,
  or CI is pending/failing.

## 4. Done gate (all required)

Not done until **all** of:

1. Worktree clean (no change-related unstaged/staged/untracked).
2. Branch pushed; not ahead of upstream.
3. **CI green** on the MR/PR — poll until pass
   (`gh pr checks --watch` or `glab ci status`); on failure, fix, push,
   re-poll. Do not proceed while pending or red.
4. **Mark ready** — once CI is confirmed green, undraft the MR/PR
   (`gh pr ready` / `glab mr update --ready`). Do not undraft before
   green.

Report the MR/PR URL and CI status. Merge stays human unless the user
asks.
