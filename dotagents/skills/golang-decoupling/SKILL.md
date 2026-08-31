---
name: golang-decoupling
description: Per-domain packages, one model per domain, adapted at boundaries.
---

# Domain Packages + Adapters

One domain package per business domain (`todo`, `users`, ...), each owning
its model and business logic. Every API boundary (HTTP, database, config,
CLI) gets its own model parsed from the domain model. A struct is a role,
never two: `Todo` in the domain package is not the `Todo` in the DB schema
or JSON payload.

## Rules

1. **Domain packages dependency-free.** No `database/sql`, `pgx`, `sqlc`,
    `net/http`, `viper`, or `json` tags (e.g. `internal/todo/`,
    `internal/users/`). Only the domain's business types (IDs, value
    objects, enum strings) plus behavior.
2. **Every boundary maps to a new model.** Database — sqlc/pgx generated
    in `internal/database/`, returns domain types. HTTP/API — ogen types
    from spec in `internal/oas/`, thin adapter in `internal/api/` (see
    `golang-api`); never sqlc rows or domain entities in a response.
    Config — native-typed structs in `internal/config/` (`time.Duration`,
    `url.URL`, `uuid.UUID`, bools), parsed in `cmd/`, never raw strings
    or viper types.
3. **Mappers live next to target model.** Adapter owns
    `fromDomain`/`toDomain`; domain never imports adapter.
4. **Business rules in domain package, not handlers.** Logic shared by
    CLI and HTTP lives in the domain (or a service over it), not DTO
    mapping.
5. **No cross-domain imports.** Domain packages don't import each other;
    cross-domain access via a service or interface the package defines.
6. **DTO-only JSON.** Marshal/unmarshal only on DTOs; domain entities
    never get `json:"..."` tags. Handler pipeline: parse request → DTO →
    domain package → service → DTO → response.

Layout: `internal/todo/`, `internal/users/` (model + service),
`internal/config/` (native types parsed in `cmd/`), `internal/database/`
(sqlc generated, maps DB rows to domain packages), `internal/oas/`
(ogen from spec), `internal/api/` (thin adapter, `oas.Handler` → domain
packages). Names are examples, not fixed.

## Checklist

- [ ] One package per domain (`todo`, `users`, ...), not a shared folder.
- [ ] Domain packages import nothing external.
- [ ] DB rows, DTOs, and config each have their own struct.
- [ ] Mappers co-located with the adapter that owns the target model.
- [ ] No sqlc/pgx types in handlers, no viper types outside `cmd/`.
