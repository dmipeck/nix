---
name: explore-fs
description: >-
  Delegate all filesystem discovery and web searching to the explore-fs
  subagent. Use any time the agent needs to find something in the filesystem —
  by filename, glob, content, or any other signal — or run any web search or
  fetch. The explore-fs subagent locates it and returns compact citations.
---

# Explore-fs

Every filesystem lookup and web search goes through the `explore-fs` subagent.
Do not do broad search work in the main thread.

## When

- Finding a file by name or pattern (`glob`-style discovery).
- Searching file contents, symbols, definitions, or usages (`grep`).
- Reading a specific file to answer a question.
- Any web search or page fetch (`webfetch`, `websearch`).

## How

1. Invoke the `explore-fs` subagent (Task tool) with the search question: what
  to find, where to look, what counts as a match.
2. It runs `glob`/`grep`/`list`/`read` for filesystem lookups and
  `webfetch`/`websearch` for web, then returns compact `path:line` citations.
3. Use its citations directly. Do not re-search the same thing yourself.

## Follow

- `caveman-explore` for the compact-citation reporting style.
- `thrifty` for cheap-model + low-effort selection.
