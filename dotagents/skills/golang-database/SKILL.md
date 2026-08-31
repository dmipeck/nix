---
name: golang-database
description: Use when working on database queries or migrations in a golang app.
  Defines the sql-first codegen workflow and database package layout, deferring
  tool specifics to golang-query (sqlc) and golang-migration (golang-migrate).
---

# Database access in Go

PostgreSQL only, SQL-first: schema and queries are the source, and Go code
is generated from them. Tool specifics live in sibling skills; this ties
them together.

## Rules

1. PostgreSQL only. Driver `github.com/jackc/pgx/v5`, pool `pgxpool`.
2. SQL-first codegen. Write schema migrations and SQL queries; generate Go
    from them via the root `generate.go` (see `golang-layout`). Nothing
    hand-written past a thin repository layer.
3. DB code lives in `./database`, queries in `./database/sql/`, migrations
    in `./migrate`.
4. sqlc generates query accessors (see `golang-query`); use its overrides
    for native types.
5. golang-migrate manages schema (see `golang-migration`); follow its
    non-destructive migration rules.
6. Schema follows `postgres` conventions: pk uuidv7, created_at/updated_at,
    soft delete, ix_/ux_/fk_ prefixes, CHECK constraints.
7. Repositories return the domain package's types; no sqlc/pgx types leak
    past the database package or into handlers (see `golang-decoupling`).
8. Every generated query gets an integration test (see `golang-testing`).

## Pool and repository

`cmd/` owns the `*pgxpool.Pool`. The database package exposes repository funcs
over generated queries, returning the domain package's types. `*pgxpool.Pool`
satisfies sqlc's `DBTX` interface, so `New(pool)` works. For transactions,
pass a `pgx.Tx` to `New(tx)`.

## Verify

`go generate ./...`
`go build ./...`
`go test -tags integration ./...`
