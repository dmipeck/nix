---
name: golang-cli
description: Golang CLI. EnvPrefix-only env binding, RunE config load.
---

# CLI with cobra + viper

cobra builds the command tree; viper reads config from env. Commands parse
config to native values and call a domain function — a thin wrapper.

## Rules

1. cobra/viper only under `./cmd/`. Native values (`time.Duration`, `url.URL`,
    `uuid.UUID`, `config.Config`) cross the boundary; viper/cobra types never
    leave `./cmd/`.
2. Env vars are the source of truth. No secrets, URLs, or ports in config files
    checked into git.
3. `SetEnvPrefix` + `BindEnv` per key, never `AutomaticEnv`.
    `AutomaticEnv` reads any env var implicitly and unpredictably.
4. Config keys are constants. One const per key in `cmd/`, never literals.
5. Load config in `RunE`, per command. No `PersistentPreRunE`.
    Each command reads only what it needs when it runs.
6. Commands are thin wrappers. `RunE` parses config, calls a domain function.
    No business logic in `cmd/`.

## Constants + EnvPrefix

`SetEnvPrefix("MYAPP")` + `SetEnvKeyReplacer` map `http.addr` to env
`MYAPP_HTTP_ADDR`. Every key is `BindEnv`-ed, so viper consults env only for
declared keys. Create a fresh viper per command and bind the keys it needs.

## Commands load their own config in RunE

No `PersistentPreRunE`, no config on context. Each command loads what it needs
in `RunE` and passes native values down.

## Thin wrapper over a domain function

The command calls a function that owns the wiring. Native types in,
composition, return. No cobra/viper, no business rules. The domain function
(`runServe` in `cmd/`, or `app.RunX`) composes; behavior lives in domain
packages (see `golang-decoupling`).

## main.go

Root `main.go` is a thin wrapper over `cmd.Execute()` — see `golang-layout`.
