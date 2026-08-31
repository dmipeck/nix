---
name: golang-migration
description: golang-migrate: go:embed, rename-over-drop, round-trip test.
---

# Migrations with golang-migrate

`github.com/golang-migrate/migrate/v4`. Migrations embedded via `go:embed`,
run programmatically — no migrate CLI in prod, no external SQL at runtime.

## Rules

1. Migrations under `./migrate/`: `./migrate/sql/` holds `.up.sql` /
    `.down.sql` files; `./migrate/` Go package `go:embed`s `sql/*.sql`,
    exposes `Up(ctx, url)` / `Down(ctx, url)`.
2. Zero-padded filenames so lexicographic == numeric
    (`000001_create_users.up.sql`). sqlc reads `./migrate/sql` as schema,
    ignores `.down.sql` (`golang-query`).
3. `./cmd/` wires migration commands to these funcs (`golang-cli`).
4. **Forward migrations non-destructive**: rename over drop so production
    data never lost. Rename target `_del_<name>` (`postgres` prefix); `down`
    strips prefix — reverses the rename, never the destructive half (a `down`
    that `DROP`s deletes data on rollback). Follow-up `DROP` of the `_del_`
    resource happens in a later migration, never in `down`.
5. **Exception:** resource added in a commit not yet merged to main never
    touched production — drop freely. No defensive migration on data that
    hasn't reached production.
6. Remove a shipped resource: rename to `_del_<name>`, ship; deploy app code
    that stops referencing old name; later migration `DROP`s the `_del_`
    resource after it has been unreferenced in production for a cycle.
7. New tables follow `postgres` conventions (pk uuid, created_at/updated_at,
    soft delete, ix_/ux_/fk_, timestamp).
8. Down = exact inverse of up, in order. Test container is the one place a
    `down.sql` `DROP` runs — throwaway data.

## Package + driver

`go:embed sql/*.sql`; `Up`/`Down` run via `gmigrate.NewWithInstance("iofs",
src, "pgx5", driver)`, tolerate `gmigrate.ErrNoChange`. Driver details: pgx/v5
registers as `"pgx5"`, takes `*sql.DB` — open via
`github.com/jackc/pgx/v5/stdlib` `sql.Open("pgx/v5", url)`. `iofs.New(fs,
"sql")` points at the embedded subdirectory.

## Round-trip test (mandatory)

Suite test: `Up` to latest, snapshot schema, `Down`, assert schema **unchanged**
from before any migration. Compare full canonical output — tables, columns,
constraints, indexes, sequences, types in `public` — not just table names, so
a down migration dropping a column/constraint is caught. Testcontainers
harness in `golang-testing`. Run: `go test -tags integration ./migrate/test/`.
