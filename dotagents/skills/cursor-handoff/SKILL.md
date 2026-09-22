---
name: cursor-handoff
description: >-
  Hand the current conversation off to a fresh background Cursor agent that
  picks up the work immediately.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff summary of the current conversation so a fresh agent can
continue the work. Instead of saving it, launch a background agent seeded with
the summary as its prompt:

```bash
cursor-agent persist --trust "<handoff summary>"
```

It starts a tmux-backed persistent session in the current working directory and
returns immediately; the user manages it with `cursor-agent persist list`,
`cursor-agent persist attach <session>`, and
`cursor-agent persist stop <session>`.

Cursor auto-names persist sessions from the workspace (`cursor-<slug>-…`);
there is no `--name` flag. Put a short descriptive title on the first line of
the summary so it is visible when the user attaches.

Include a "suggested skills" section in the summary, naming which skills the
next agent should call the Skill tool for.

Do not duplicate content already captured in other artifacts (specs, plans,
ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally
identifiable information, since the summary becomes the agent's prompt.

If the user passed arguments, treat them as a description of what the next
session will focus on and tailor the summary accordingly.
