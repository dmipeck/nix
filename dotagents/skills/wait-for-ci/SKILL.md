---
name: wait-for-ci
description: >-
  Wait for CI by polling individual jobs, not the pipeline as a whole. Fail
  fast on any hard job failure; when all jobs finish clean, sanity-check
  pipeline status before reporting OK. Use when waiting for CI, GitHub
  Actions, GitLab pipelines, check runs, or after push/PR when the agent must
  know whether CI passed.
---

# Wait for CI

Watch **jobs**, not the aggregate pipeline/workflow. Aggregate status often
stays "pending"/"running" until every job finishes — that hides early failures
and wastes the wait.

## Loop

1. **Resolve** the target run: PR/MR, branch, commit SHA, or explicit
   pipeline/workflow id. Prefer the run for the HEAD just pushed.
2. **List jobs** for that run (refresh each poll). Track each job's
   conclusion/status and whether it is **allowed to fail**.
3. **Fail fast:** if any job has failed and is **not** allowed to fail → stop.
   Report the pipeline/run as **failed** (job name, conclusion, URL/id). Do
   not wait for remaining jobs.
4. **Continue** while any job is queued/running/pending (or not yet created
   when the matrix/DAG is still expanding). Poll again after a short backoff
   (start ~15–30s; back off up to ~60s). Prefer `AwaitShell` / sleep tools
   over busy loops.
5. **All jobs terminal** and none hard-failed → **sanity-check** any available
   aggregate **pipeline / workflow / check-suite status**.
   - Green / success → report **OK**.
   - Not green → report **failed** (or blocked/cancelled/unknown) with the
     aggregate status and any odd job conclusions — do not claim OK.
6. **Timeout:** if the user set a deadline, stop when it hits and report
   still-running jobs. Otherwise keep polling until step 3 or 5.

Allowed-to-fail jobs (GitLab `allow_failure`, GitHub continue-on-error /
optional checks, soft required-status exclusions) **never** alone make the
wait fail. Ignore their failures for the fail-fast rule; still wait for them
to finish before the final sanity check so the aggregate status is stable.

## Platform notes

Use whatever CLI/API the repo already uses (`gh`, `glab`, MCP). Map the same
loop onto local names:

| Concept | GitHub Actions | GitLab CI |
|---|---|---|
| Run | workflow run | pipeline |
| Unit | job (and check-run) | job |
| Soft fail | continue-on-error / optional | `allow_failure` |
| Aggregate | workflow / check suite | pipeline status |

**GitHub (examples):**

```bash
gh run list --commit <sha> --limit 5
gh run view <run-id> --json status,conclusion,jobs,url
# or: gh api .../actions/runs/<run-id>/jobs
```

Treat a job as hard-failed when `conclusion` is `failure` (or
`timed_out` / `startup_failure`) and it is not continue-on-error. Cancelled
by a newer push → report **superseded**, not OK.

**GitLab (examples):**

```bash
glab ci status
glab ci view
glab api "projects/<id>/pipelines/<pipeline-id>/jobs"
```

Hard-fail when `status`/`failure` and `allow_failure` is false. Pipeline
statuses to accept as green on the sanity check: `success`. Treat `failed`,
`canceled`, `skipped` (whole pipeline), `blocked` as not OK unless the user
explicitly accepts that state.

## Report shape

Keep the final reply short:

- **OK** — all jobs done, no hard failures, aggregate status green.
- **Failed** — first hard-failed job (name + link); aggregate if any.
- **Superseded / timed out / blocked** — say which; list unfinished jobs when
  relevant.

Do not dump full job logs unless asked or needed to name the failing step.
