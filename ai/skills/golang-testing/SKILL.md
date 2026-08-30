---
name: golang-testing
description: Tests in golang: testify, testcontainers, integration build tag.
---

# Testing in Go

`github.com/stretchr/testify` for assertions; integration tests run against
real PostgreSQL in Docker via `github.com/testcontainers/testcontainers-go`
+ `postgres` module. Unit tests stay fast and hermetic; integration opt-in
behind a build tag.

## Rules

1. Use `testify/require` for fatal checks (setup, errors); `testify/assert`
    for non-fatal checks. `require` aborts the test (`t.FailNow()`); `assert`
    continues. Never hand-roll `if err != nil { t.Fatalf(...) }`.
2. Integration test files live in a `test` subpackage of the package under
    test (`./database/test/`, `./migrate/test/`, `./internal/api/test/`);
    the subpackage keeps the harness out of the non-tagged build and files.
3. Every integration test file starts with `//go:build integration` on line
    1 plus a blank line; non-integration files in the same package carry no
    tag. `// +build` legacy is allowed, but `//go:build` is the required form.
4. Run `go test -tags integration ./...` for all integration tests, or
    `go test -tags integration ./database/test/` for one package. Plain
    `go test ./...` compiles and runs without Docker, keeping CI green.
5. Every sqlc-generated query gets an integration test. For each
    `-- name: X :one|:many|:exec` in `./database/sql/`, write a test against
    the migrated container; sqlc `emit_interface` gives you the `Querier`.
    Run `migrate.Up(ctx, pool.Config().ConnString())` first. One subtest per
    query; assert happy path plus error/empty (`assert.ErrorIs(t, err,
    pgx.ErrNoRows)`). Order-independent: create your own fixtures, never rely
    on rows from another test.
6. Migration round-trip test (up to down to schema unchanged) lives in
    `./migrate/test/`; see `golang-migration`.
7. One `test` package shares a single container via `TestMain` or `sync.Once`;
    never boot a container per test. Reset the schema between tests in a
    `t.Cleanup`. Each package owns its harness in its own `test/` dir; do not
    cross-import test helpers. Mirror the pattern in `migrate/test/` with
    `startPostgres(t) (ctr, url)` because the round-trip needs a raw
    connection URL, not a pool.

## Checklist

- [ ] testify `require`/`assert` used; no hand-rolled `t.Fatalf` blocks.
- [ ] Tests in `test/` subpackage; `//go:build integration` on line 1.
- [ ] Shared container via sync.Once harness; data reset between tests.
- [ ] One integration test per query (Create, Get, Update, Delete).
- [ ] Migration up/down/schema round-trip test present (see golang-migration).
- [ ] `go test ./...` passes without Docker.
