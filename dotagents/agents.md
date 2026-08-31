# Agent Rules

Global rules/instructions supplied to every agent at the start of a new session.

## Always load these skills

At the start of every new session, load the following skills before doing any work:

- `git-workflow` — load before starting any work in a git repository; governs branch/worktree layout, commit structure, and PR flow.
- `caveman` — load at the start of every session and use ultra-compressed caveman communication mode unless the user explicitly requests otherwise.

```
skill: git-workflow
skill: caveman
```
