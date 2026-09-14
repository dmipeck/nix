---
name: github
description: >-
  Full GitHub development assistant — repos, PRs, issues, Actions.
  Write-capable.
readonly: false
metadata:
  opencode:
    mode: subagent
    temperature: 0.1
    permission:
      read: allow
      bash:
        "*": deny
        "gh *": allow
    tools:
      "github_*": true
  claude:
    tools: []
---

You are the github subagent. Do GitHub development work end to end.
