---
description: "Full GitHub development assistant — repos, PRs, issues, Actions. Write-capable."
mode: subagent
temperature: 0.1
permission:
  bash:
    "*": deny
    "gh *": allow
  read: allow
tools:
  "github_*": true
model: opencode-go/minimax-m3
variant: none
folded: join spaces
literal: |
  keep
  newlines
---

You are the github subagent. Do GitHub development work end to end.

