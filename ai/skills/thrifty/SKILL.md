---
name: thrifty
description: >-
  Keeps token use down. Use when `/thrifty`, delegating to subagent, or needs
  to perform mechanical job
---
# Thrifty

Cost = tokens in (context) + out + model price per token. Cut all three.

1. Explore → subagent. Exact question, want `path:line` cites back. Never
    re-search own context. Direct read only when file already known.
2. Cheapest model that fits. OpenCode Zen FREE tier first (`/models`,
    `opencode models`). Paid only for work free tier cannot do.
3. Lowest reasoning/effort that lands task. Escalate only for hard problems
    (new design, security, concurrency, data bugs).
4. Caveman replies (`/caveman`; `/caveman ultra` for mechanical work).

Cheap is wrong when: security, destructive ops, multi-step where dropped word
misleads, or human-read artifacts (comments, commits, docs, PR bodies).

Cheap for search, think, talk. Never cheap for facts.
