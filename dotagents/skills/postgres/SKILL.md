---
name: postgres
description: >-
  Use when working on a postgres schema in any app. Defines schema
  conventions: NOT NULL by default, uuidv7 pk keys, created_at/updated_at,
  soft delete, _del_ prefix, ix_/ux_/fk_ prefixes, CHECK constraints,
  and timestamps without timezone.
---

# PostgreSQL Schema Conventions

Fixed DDL conventions, consistent across services and clients. Apply to every
table; deviations need a stated reason.

## Rules

1. **Columns are `NOT NULL` unless stated otherwise.** Nullability is opt-in
    (`deleted_at`, optional fields). A column holding a value is `NOT NULL` in
    the schema even if the app validates too.
2. **Primary key is a `uuid` column named `pk`** (not `id`). Default is
    `uuidv7()` — time-ordered and index-friendly.
3. **Every new table gets `created_at` and `updated_at`** —
    `timestamp` default `now()`. The app (or a trigger) maintains
    `updated_at`; never hand-set it.
4. **Prefer soft delete** — a nullable `deleted_at` over hard `DELETE` where a
    row matters to history, audit, or referential integrity. Queries filter
    `WHERE deleted_at IS NULL`; a delete is `UPDATE ... SET deleted_at = now()`.
    Hard delete is fine for scratch and child data.
5. **Index naming by kind:** plain: `ix_<table>_<col>`; unique:
    `ux_<table>_<col>`; foreign key: `fk_<table>_<reftable>` (constraint on the
    FK column).
6. **Prefer `timestamp` over `timestamptz`** where an instant is wall-clock. Use
    `timestamptz` only when an absolute instant matters across timezones.
7. **Add a `CHECK` constraint to any format-specific column** — email, ISO
    codes, URLs, currency, text enums. The DB enforces shape even when the app
    validates, so bad data cannot enter via any path.
8. **Soft-delete schema objects with a `_del_` prefix instead of dropping.**
    Rename a table, column, index, or constraint holding data with the `_del_`
    prefix so the data survives and removal stays reviewable and reversible.
    Drop the `_del_`-object only later, once it is unreferenced in production
    for a cycle. The `down` migration reverses the rename (strips the prefix);
    never drop. Rename dependent indexes and constraints along with the table.
    Pairs with the non-destructive rule in `golang-migration`.
