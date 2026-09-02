---
name: check-repo
description: >-
  Check an unfamiliar repo into a verified green state in one pass: survey
  the checkout, ensure a flake devshell (creating one when missing), install
  dependencies inside the devshell, verify the build, run the full test suite
  to green, and smoke-test the app. Use when the user says "check this repo",
  "check-repo", "is this repo healthy", "get this building", "verify this
  project", "does this build even work", "make this build on my machine", or
  hands you a third-party checkout to verify before you rely on it. Old
  adopt-family phrases ("adopt this repo", "onboard a new project") still
  route here — adopting is just what you call it once every gate is green —
  even when they never say Nix or devshell.
---

# Check Repo

A repeatable flow that checks an unfamiliar checkout into a verified green
state on this Nix-based setup. Each numbered step is a runnable gate on the
previous: a step fails → stop, quote the shortest decisive error line
verbatim, iterate narrowly (max one or two fix attempts on setup
mechanics), then stop and report. Never
paper over a skipped or failed gate, never invent a pass, never silently fall
back to the host toolchain. Agent has file + bash tools and follows
`git-workflow`.

## 1. Survey

Identify project root and ecosystem. Manifest heuristics:

| Manifest | Ecosystem |
|---|---|
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `package.json` | Node — read lockfile: `package-lock.json`→npm, `pnpm-lock.yaml`→pnpm, `yarn.lock`→yarn |
| `pyproject.toml` / `setup.py` / `requirements.txt` | Python |
| `CMakeLists.txt` / `Makefile` | C/C++ / generic-make |
| `mix.exs` | Elixir |
| `pom.xml` / `build.gradle` | JVM |

Then read, in order of trust: `README`*, `AGENTS.md`/`CLAUDE.md`, and the CI
workflows (`.github/workflows/*`, `.gitlab-ci.yml`, `.circleci/config.yml`,
`.buildkite/*`, `azure-pipelines.yml`, `Jenkinsfile`). CI is the
highest-trust source of the canonical build / test / run commands — it wins
over heuristics. Never assume a build command you did not verify exists; if CI
documents one, use it verbatim. Record the exact CI commands for the steps
below before touching anything.

## 2. Ensure a flake devshell exists

Present if `flake.nix` exists **and** `nix flake show` lists
`devShells.<system>.default` (accept legacy top-level `devShell.<system>`).
Present → use it as-is, do not rewrite. Absent → create a self-contained
minimal `flake.nix` at project root with a `devShells.default` containing the
detected toolchain:

```nix
{
  description = "check-repo devshell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [ <toolchain> ];
          };
        });
    };
}
```

Toolchain → nixpkgs packages:

| Ecosystem | packages entry |
|---|---|
| Rust | `rustc` `cargo` |
| Go | `go` |
| Node | `nodejs` plus `pnpm` (pnpm lock) or `yarn` (yarn lock); npm ships with nodejs |
| Python | `python3` plus `uv` when `uv.lock` present; if `python3 -m pip` is absent, use `python3.withPackages (p: [ p.pip ])` |
| C/C++ / make | `gcc` or `clang` `cmake` `make` |
| Elixir | `elixir` |
| JVM | `jdk` `gradle` / `maven` |

Use plain flake for third-party checkouts; flake-parts optional. Want the full
linter + pre-commit rig too → that is `/scaffold`, not here — do not duplicate
it. If `flake.lock` is missing, run `nix flake lock`.

**Gate:** `nix develop --command true` must exit 0 (non-interactive eval
proof). Never claim the devshell works without this proof.

## 3. Install dependencies inside the devshell

Every command in this flow runs through the devshell — `nix develop --command
<cmd>` or equivalent non-interactive invocation — never on the host toolchain.
Match the lockfile:

| Ecosystem | Command |
|---|---|
| Rust | `cargo fetch` (workspace-aware; run at workspace root) |
| Go | `go mod download` |
| Node | `npm ci` / `pnpm install --frozen-lockfile` / `yarn install --frozen-lockfile` (match lockfile) |
| Python | `uv sync` when `uv.lock`, else `python -m pip install -e .` |
| C/C++ / make | skip pure fetch unless CMake external projects (fetched at configure) |
| Elixir | `mix deps.get` |
| JVM | `mvn dependency:go-offline` / `gradle dependencies` |

**Gate:** exit 0. Ecosystem with no row → CI command, else ask.

## 4. Verify the build

Prefer the CI-documented build command verbatim; fall back per ecosystem:

| Ecosystem | Command |
|---|---|
| Go | `go build ./...` |
| Rust | `cargo build` or `cargo build --workspace --all-targets` |
| Node | `npm run build`, else the CI typecheck step |
| Python | `python -m build`, else re-prove with `pip install -e .` |
| C/C++ / make | `cmake -B build && cmake --build build`, else `make` |

**Gate:** exit 0.

## 5. Run the tests; all must pass

Prefer the CI-documented test command; fallback table:

| Ecosystem | Command |
|---|---|
| Go | `go test ./...` |
| Rust | `cargo test` |
| Node | `npm test` / `pnpm test` / `yarn test` |
| Python | `pytest` |
| C/C++ / make | `make test` |

Green gate: whole suite once, exit 0, all pass. Suite needs external services
(DB, network)? State that and stop to ask — never fake a pass. Summarize counts
(e.g. "42 passed, 3 skipped").

## 6. Smoke-test the application

Launch the built app the way CI/docs do:

- CLI → run with `--help` / `--version` or a trivial invocation; expect exit 0.
- Server/app → start in background with a timeout, probe the documented
  endpoint (`curl` health/root), then kill cleanly.

Capture one decisive output line as evidence. Never leave stray processes.

## 7. Report + handoff

Report a per-gate result table: gate, exact command run, decisive evidence line
(exit 0 or the verbatim error). List the files created (`flake.nix`,
`flake.lock`). Per `git-workflow`: if the project is a git repo, these
artifacts become their own commit, separate from any pre-existing user
changes; never auto-push; never touch pre-existing uncommitted changes.

## Failure protocol

Stop condition: a gate fails or the project needs external services you cannot
satisfy. Quote the shortest decisive error line verbatim. Max one or two fix
attempts on setup mechanics (missing nixpkgs package, wrong lockfile
command); past that, stop and report what blocks. Never report a skipped or
failed gate as done.
