---
name: tester
description: >-
  Delegate every test run to the tester subagent. Use before any testing —
  when the user says "run the tests", "check the tests pass", or reports a
  failing test. The tester runs the suite, reviews the output, and reports
  pass/fail without taking corrective action. Spawn one tester subagent per
  distinct testing ecosystem in the repo.
---

# Tester

Every test run goes through the `tester` subagent. Do not run test suites or
judge test output in the main thread.

## When

- Before running any tests.
- User asks to run the tests, check the tests, or debug a failing test.
- Verifying a change is ready (tests must pass before commit/merge).

## How

1. Enumerate the distinct testing ecosystems in the repo (e.g. Go, JS/TS,
  Python, ...). One ecosystem per tester subagent.
2. Invoke the `tester` subagent (Task tool) per ecosystem with the ecosystem
  name and the scope (package, file, or full suite). It determines and runs
  the suite itself.
3. If it reports failures, relay the report to the user. Do not fix, re-run,
  or hide failures yourself.

## Model

Run the tester on the cheapest model that fits — running a suite and reporting
failures is mechanical, so low reasoning/effort lands it. Before invoking,
check for free opencode model access (`/models`, `opencode models`) and prefer
a free model over any paid one. Escalate only when test output is
undiagnosable and a stronger model would help read it.

## Follow

- `golang-testing` (and per-ecosystem skills) for how the tester runs each
  suite.
- `thrifty` for cheap-model + low-effort selection.
- `git-workflow` for when tests must pass (before commit/merge).
