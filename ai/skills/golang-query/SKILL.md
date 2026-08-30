---
name: golang-query
description: >-
  Use when working on sqlc queries in a golang app. Defines the sqlc codegen
  workflow: sqlc.yaml, native-type overrides over pgtype, query files, and
  regeneration via the root generate.go.
---
# sqlc query codegen

sqlc generates type-safe Go accessors from hand-written SQL. This skill
owns the query side; see `golang-database` (layout) and `postgres` (schema).

## Rules

1. Queries live under `./database/sql/` (sqlc input); generated Go lands in
    `./database` (`package: database`, `out: ./database`).
2. `sql_package: pgx/v5`. `schema` points at `./migrate/sql`; migration
    files double as sqlc's schema.
3. **Avoid `pgtype.*`.** Overrides map Postgres types to native Go:
    `float64`, `time.Time`, `github.com/google/uuid.UUID`. `pgtype` opt-in
    for weird types (e.g. `numeric`).
4. Regenerate via root `generate.go` (see `golang-layout`):
    `//go:generate go tool sqlc generate`, run `go generate ./...`. sqlc
    pinned in `go.mod` (`tool` directive), not host/devShell install.
5. Every generated query gets an integration test (see `golang-testing`).

## sqlc.yaml

- `emit_interface: true`, `emit_empty_slices: true`.
- `emit_pointers_for_null_types: true` (optional) → nullable columns as
    `*time.Time`/`*uuid.UUID` instead of `pgtype.*`.
- Columns with defaults (`uuidv7()`, `now()`) generate non-null
    `uuid.UUID`/`time.Time`; inserts use `RETURNING`.
- `bigint`→`int64`, `float8`→`float64` are defaults, kept explicit.
- `numeric` has no lossless native type — leave `pgtype.Numeric` or map to
    string; never money through `float64`.

## Queries

- One file per aggregate. Annotate every query
    `-- name: X :one|:many|:exec|:execrows`. `$1, $2` positional params.
- Soft delete: every `SELECT` filters `deleted_at IS NULL`; "delete" is
    `UPDATE`, not `DELETE FROM` (schema side in `postgres`). uuid columns
    come back `uuid.UUID`, timestamps `time.Time`.

## Regenerate + verify

- `go generate ./...` (root `//go:generate go tool sqlc generate`),
    `go build ./...`, `go test -tags integration ./database/...`.
