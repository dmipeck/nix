---
name: comments
description: >-
  Calm down with comments. Use when adding comments, "comment this code",
  "comment this function", explaining code in comments, or reviewing diff
  full of what-comments
---
# Comments

Calm down. Too many comments. Code read itself. Reader no need narrator.

## Law

**Comment never say what code do.** Code already say. Redundant comment = noise.

```go
// Increment counter.  <- NO. Code say this already.
count++
```

Only write comment when code do something **unusual** that confuse reader.
  Then say **why**, not what.

```go
// No early return: need counter++ to run on both paths.
if retry {
  count++
}
```

## What-comment OK where?

Documentation only. **Public surface = doc territory.** Those get
  long what-comment:

- Public function / method (doc comment)
- Public class / struct / type
- Package / module doc
- Public constant

Those = API. Reader call from outside, cannot see body. Tell them what,
  contract, behavior, args, returns. Internal guts no.

Private function, private field, internal var, inline statement → no
  what-comment. Only why-comment if unusual.

## Test

Before comment, ask: "Reader need this?" If answer "see code dumb" → delete
  comment. If "without this, reader confused why" → keep, write why.

Comment that survive:
- **why** for unusual choice (workaround, perf trick, order matter, historical
  reason, constraint)
- doc comment on public surface

Comment that die:
- what code do
- "we do X" restating next line
- obvious "increment", "loop over items", "set value"
- "TODO fix" without reason (ok only: TODO + why)

## Reminder

Code clear? No comment needed. Good code need zero inline comment. Clean code
  with one why-comment beat dirty code with ten what-comments.
