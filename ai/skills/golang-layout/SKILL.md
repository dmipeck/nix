---
name: golang-layout
description: Golang app project structure: layout, main.go/cmd/, generate.go.
---

# Go Project Layout

Layout follows boundaries: domain at center, adapters around, entry thin.

## Rules

1. **Single binary** → `main.go` at root. No binary dir.
2. `main.go` thin: only `cmd.Execute()`. No logic, config, flags.
    CLI wiring (root, subcommands, env config, thin wrappers) is
    `golang-cli` territory.
3. Root cobra command under `./cmd/`; subcommands are files under
    `./cmd/`.
4. Business logic in per-domain packages (`internal/todo/`,
    `internal/users/`); each boundary adapted via role-specific model.
    See `golang-decoupling`.
5. HTTP APIs generated from OpenAPI spec with ogen; generated code
    only under `./internal/`. See `golang-api`.
6. Database: `./database` package, queries under `./database/sql/`
    (sqlc accessors), migrations under `./migrate`. See
    `golang-database`, `golang-query`, `golang-migration`.
7. Integration tests in `test` subpackage, `//go:build integration`,
    testcontainers. See `golang-testing`.
8. Root `generate.go` holds every `//go:generate`; `go generate ./...`
    regenerates all code. Same `package main` as `main.go`, no build
    tag (one hides directives from plain `go generate`); only
    directives + package clause. See `golang-query`, `golang-api`.
9. Codegen tools are Go tools pinned in `go.mod` via `tool` directive
    (`go get -tool <cmd>@vX.Y.Z`), invoked as `go tool <name>` in
    `//go:generate`; never host/devShell install. `go install` only
    non-codegen tools (linters run by pre-commit). Keeps nix develop
    and CI identical — no generator on `PATH` beyond Go.

## Checklist

- [ ] `main.go` at root, only `cmd.Execute()`.
- [ ] Root `generate.go` holds all `//go:generate` directives.
- [ ] Codegen tools pinned in go.mod, invoked via `go tool` (no
    host/devShell install).
- [ ] `cmd/` tree holds the CLI (see golang-cli).
- [ ] Config parsed to native types before leaving `cmd/`.
- [ ] No secrets in config files.
