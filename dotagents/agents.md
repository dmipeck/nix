# Agent Rules

Global rules/instructions supplied to every agent at the start of a new session.

## Always load these skills

At the start of every new session, load the following skills before doing any work:

- `git-workflow` — load before starting any work in a git repository; governs branch/worktree layout, commit structure, and PR flow.
- `caveman` — load at the start of every session and use ultra-compressed caveman communication mode unless the user explicitly requests otherwise.
- `commit` — load before any commit; delegate commit message writing and execution to the commit subagent.
- `test` — load before any testing; delegate all test runs to the test subagent.
- `explore-fs` — load before any filesystem discovery or web searching; delegate finding files by name/content and all web lookups to the explore-fs subagent.

```
skill: git-workflow
skill: caveman
skill: commit
skill: test
skill: explore-fs
```
