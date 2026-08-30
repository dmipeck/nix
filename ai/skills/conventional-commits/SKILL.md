---
name: conventional-commits
description: >-
  Write conventional commit messages and pick the right type. Use when
  writing a commit, choosing feat/fix/refactor/docs/test/ci/build/style, or
  when the user says "commit this" — even if they never name the format.
---

# Conventional Commits

Format `<type>(<scope>): <subject>`, optional body + footer. Commit-msg hook
enforces it, so every commit must conform. Type + scope keep history
skimmable for humans and machines — `git log`, changelogs, blame.

## Types

Pick the type from actual content, not the overall task:

- `feat:` user-facing capability or behavior change; someone notices or
  benefits once shipped.
- `fix:` corrects a bug a user could hit — wrong output, broken behavior,
  crash, regression.
- `refactor:` internal restructuring, no behavior change.
- `build:` build system, deps, tooling. `ci:` CI config.
- `docs:` documentation. `test:` tests. `style:` formatting only.
- `chore:` deprecated catch-all; only when nothing else fits.

### Not `feat:`
Scaffolding, plumbing, config, groundwork for a future feature, types with no
caller yet. Needs the caveat "user won't see anything yet"? Not `feat:`.

### Not `fix:`
Fixing what never shipped, ran, or diverged from intent — comment typo, dead
code, tightening a type never wrong at runtime. Save `fix:` for behavior
users could hit.

## Scope

Optional, use when it adds signal: `feat(auth): ...`. Name the component or
package touched; skip when the change is one obvious area.

## Subject + body
Imperative, ≤50 chars, no trailing period. Describe the change, not the
process. Body explains why, not what — the diff already shows what; note
tradeoffs, context. Breaking change: `BREAKING CHANGE:` footer or `!` after
type/scope (`feat!: ...`). Reference issues in footer (`Closes #123`).

## Bad message?
Never push a second "oops" commit. Amend or rebase before merge so history
reads as written right the first time.
