---
name: golang-api
description: OpenAPI-driven codegen: ogen server/client, OIDC, thin handler.
---

# API creation with ogen / OpenAPI

## Rules

1. **Spec is source of truth.** Change API → edit spec → regenerate. Never
    hand-edit generated files.
2. **Generated code only under `./internal/`** (`./internal/oas/`); spec
    lives outside `internal/` (e.g. `api/openapi.yml`).
3. Adapter is a **thin wrapper**: implements `oas.Handler`, embeds
    `oas.UnimplementedHandler` (methods default "not implemented"), delegates
    to domain packages — mapping layer, not logic layer. Compile-time check
    `var _ oas.Handler = (*Handler)(nil)`.
4. ogen generates server + client from same spec (`paths/server` +
    `paths/client`). Client reused for integration tests.
5. Generated types map OpenAPI formats to Go natives: `uuid` → `uuid.UUID`,
    `date-time` → `time.Time`, plus `Opt*`/`Nil*` for optional/nullable.
6. Handlers return generated response sum type (`*PetRes`, `*UserRes`), not
    domain types. Map at boundary. Optional `oas.NewOptX(...)`, required plain
    assignment, nullable `oas.NilX`/`oas.NewNilX`.
7. Errors: typed error response (`&oas.Error{...}`) or Go error; middleware
    maps unhandled errors.

## Auth

Prefer **OIDC and/or OAuth2** over custom tokens, session cookies, static API
keys. Declare `securitySchemes` in spec, attach `security` per operation; ogen
generates the security handler. Implement `oas.SecurityHandler`: validate token
against IdP — JWKS fetch + `alg` + `iss`/`aud`/`exp` for OIDC, token exchange
for OAuth2. Map subject into domain model, pass via `context.Context`; handlers
never re-parse token. Long-lived machine clients: OAuth2 client-credentials.

## Install + config

ogen pinned in `go.mod` (`tool` directive), run `go tool ogen`. Never
host/devShell install. Wired through root `generate.go`:
`//go:generate go tool ogen --target internal/oas --clean api/openapi.yml`.
`.ogen.yml` at root auto-discovered; enable `paths/server`, `paths/client`,
`ogen/otel`, `disable_all: true`, `ignore_not_implemented: ["all"]`.

## Wire + tests

`oas.NewServer(handler, opts...)` returns `http.Handler`; `cmd/serve.go` thin
wrapper (`golang-cli`). Middleware (otel, logging) as `http.Handler` wrappers.
Generated client `oas.NewClient(url)` drives same spec; use in
`internal/api/test/` integration tests — `golang-testing`.
