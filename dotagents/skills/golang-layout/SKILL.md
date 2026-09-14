---
name: golang-layout
description: >-
  Golang module/app layout per go.dev: project shapes, internal/,
  cmd/<name>/, generate.go. Use when scaffolding or reviewing a Go repo
  tree, choosing where packages and binaries live, or deciding root vs
  internal/ vs cmd/.
---

# Go Project Layout

Follow
[Organizing a Go module](https://go.dev/doc/modules/layout).
Default for apps this skill targets: **server / single command** — logic
under `internal/`, installable program under `cmd/<name>/`. Domain at
center, adapters around, entry thin.

## Rules

1. One module; `go.mod` at the project root. A package's name matches the
   last component of its import path.
2. Prefer `internal/` for supporting packages. Other modules cannot
   import `internal/`, so the API can change without breaking external
   users. Keep packages in `internal` as much as possible.
3. Each package lives in its own directory (hierarchy OK). Split a
   package across multiple files in that directory; all declare the same
   `package` name.
4. **Project shapes** — pick the matching one:
   - **Basic package:** all code at root, `package <modname>`.
   - **Basic command:** `package main` at root (`main.go` or any name);
     `go install <module>@latest`. Prefer `cmd/<name>/` once anything
     non-trivial lands beside it (other dirs, multiple files, or a
     future second binary).
   - **Command/package + support:** supporting pkgs under `internal/`
     first.
   - **Multiple packages:** one dir per importable package; still prefer
     `internal/` for anything not meant as public API.
   - **Multiple commands:** one directory per program with
     `package main`; shared code in top-level `internal/`. Nest under
     `cmd/<name>/` (required when the module also exports packages).
     Install: `go install <module>/cmd/<name>@latest`.
   - **Server (default app):** no packages for export — implement logic
     under `internal/`, keep commands under `cmd/<name>/`. If a package
     becomes useful to share, split it into a separate module.
5. `cmd/` holds **installable** `package main` programs only
   (`cmd/<name>/main.go`). Not a library package. Cobra/CLI wiring lives
   in the same `cmd/<name>/` directory as `package main` (see
   `golang-cli`).
6. Business logic in per-domain packages under `internal/`
   (`internal/todo/`, `internal/users/`); each boundary adapted via
   role-specific model. See `golang-decoupling`.
7. HTTP APIs generated from OpenAPI with ogen; generated code only under
   `internal/` (e.g. `internal/oas/`). Spec lives outside `internal/`
   (e.g. `api/`). See `golang-api`.
8. Database Go code under `internal/database/`; SQL queries under
   `internal/database/sql/`; migrations under `internal/migrate/`. See
   `golang-database`, `golang-query`, `golang-migration`.
9. Integration tests in a `test` subpackage, `//go:build integration`,
   testcontainers. See `golang-testing`.
10. All `//go:generate` directives live in one file:
    `internal/tools/generate.go` (`package tools`; only directives +
    package clause). `go generate ./...` regenerates everything. See
    `golang-query`, `golang-api`.
11. Codegen tools pinned in `go.mod` via `tool` (`go get -tool
    <cmd>@vX.Y.Z`), invoked as `go tool <name>` in `//go:generate`;
    never host/devShell install. `go install` only non-codegen tools
    (linters run by pre-commit). Keeps nix develop and CI identical.

## Default tree (server / single binary)

```
project-root/
  go.mod
  api/                 # non-Go (e.g. openapi.yml)
  cmd/
    <name>/
      main.go          # package main; thin entry
      ...              # cobra files, same package main
  internal/
    <domain>/          # business packages
    api/               # HTTP adapter
    config/
    database/
      sql/             # sqlc input
    migrate/
      sql/             # *.up.sql / *.down.sql
    oas/               # ogen output
    tools/
      generate.go      # all //go:generate
```

`<name>` is typically the module's last path segment. `main` only wires
and calls `Execute()` (or equivalent) in the same package — no logic,
config parsing owned by command `RunE`, no flags outside cobra setup.
See `golang-cli`.

## Checklist

- [ ] Layout matches a go.dev project shape; apps default to server.
- [ ] No export packages unless this is intentionally a library module.
- [ ] Supporting packages under `internal/`.
- [ ] Each installable program is `cmd/<name>/` with `package main`.
- [ ] `internal/tools/generate.go` holds all `//go:generate` directives.
- [ ] Codegen tools pinned in go.mod, invoked via `go tool`.
- [ ] Config parsed to native types before leaving `cmd/<name>/`.
- [ ] No secrets in config files.
