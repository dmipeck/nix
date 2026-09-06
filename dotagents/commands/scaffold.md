---
description: Scaffold a new project with a flake-parts flake.nix, a Nix
  devShell full of formatters, linters and language servers, and pre-commit
  wired to run them all.
---

Scaffold a new software project in the current directory. If the directory is
not already a git repo, run `git init` first (pre-commit requires it).

## Identify the repo's languages

Before scaffolding, determine what the project actually is:

1. **Glob for sources** — map files to languages: `*.nix` = Nix; `*.md` =
   Markdown; `*.go` / `go.mod` = Go; `*.rs` / `Cargo.toml` = Rust; `*.py` /
   `pyproject.toml` = Python; `*.ts` / `*.tsx` / `*.js` / `*.jsx` /
   `package.json` = TypeScript or JavaScript; `*.sh` = Shell; `*.rb` /
   `Gemfile` = Ruby. Check existing config like `.golangci.yml`,
   `.eslintrc*`, or build definitions for hints about already-intended
   tooling. Empty or nearly empty dir means the project is new — infer the
   intended language from the directory name and any README.
2. **Use the tool table** — for each detected language take its formatters,
   linters and LSP from the table below.
3. **Verify against nixpkgs** — confirm every tool exists in nixpkgs
   (`nix search nixpkgs <tool>`) before adding it. Do not invent a tool from
   memory; the table lists only names verified against nixos-unstable.
4. Ask the user for the project name if not obvious from the directory; confirm
   the detected language set and the tool list before writing files, but
   proceed with sensible defaults if the user has no preference.

"Relevant tools" below always means the base Nix tooling (pre-commit,
gitleaks, nixfmt, editorconfig-checker) plus every formatter, linter and LSP
listed for the detected languages in the table.

## Tool table (2026 community defaults)

| Language | Formatters | Linters | LSP |
|---|---|---|---|
| Nix | `nixfmt` | `statix`, `deadnix` | `nixd` (`nil` alt) |
| Markdown | `markdownlint-cli2` | `markdownlint-cli2` | `marksman` |
| Go | `gofmt` in `go`, `goimports` in `gotools` | `golangci-lint` | `gopls` |
| Rust | `rustfmt`, `clippy` | `clippy` | `rust-analyzer` |
| Python | `ruff` (format) | `ruff` (lint) | `pyright` (`basedpyright` alt) |
| TypeScript / JS | `biome` | `biome` | `typescript-language-server` |
| Shell | `shfmt` | `shellcheck` | `bash-language-server` |

LSPs are editor-side: they belong in the devShell `PATH` only — never in
pre-commit hooks. Formatters and linters get both a pre-commit hook and a
devShell entry. For a language missing from the table, web-search its current
community default, verify the nixpkgs package name, then add a row.

## What to create

1. `flake.nix` — flake-parts based. A `devShells.default` that installs
  pre-commit, gitleaks, nixfmt, editorconfig-checker, plus every
  language-relevant formatter, linter and LSP from the tool table. The shell
  hook installs the pre-commit git hooks.
2. `.pre-commit-config.yaml` — a `conventional-commits` hook plus one hook
  per formatter/linter, using the binaries from the devShell
  (`language: system`). LSPs are never hooked.
3. `.editorconfig` — minimal base that editorconfig-checker can validate
  against.
4. `.gitignore` — sane defaults (`result`, `.direnv`). Lock files must be
  committed, never ignored.

## flake.nix

Use flake-parts. No other framework dependencies. Do not add
`pre-commit-hooks.nix` — hooks live in the checked-in
`.pre-commit-config.yaml` instead, so pre-commit config stays visible and
portable.

```nix
{
  description = "<project-name>";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin"
      "aarch64-darwin" ];

      perSystem = { pkgs, ... }:
        let
          # Base Nix tooling always; uncomment the row(s) for each detected
          # language (formatter, linter, LSP).
          tools = with pkgs; [
            pre-commit
            gitleaks
            nixfmt
            editorconfig-checker
            # Go: golangci-lint gopls gotools
            # Rust: clippy rust-analyzer rustfmt
            # Python: pyright ruff
            # TypeScript/JS: biome typescript-language-server
            # Markdown: markdownlint-cli2 marksman
            # Shell: bash-language-server shellcheck shfmt
          ];
        in
        {
          devShells.default = pkgs.mkShell {
            packages = tools;
            shellHook = ''
              pre-commit install --hook-type pre-commit --hook-type \
              commit-msg --overwrite
            '';
          };
        };
    };
}
```

## .pre-commit-config.yaml

`conventional-pre-commit` comes from its upstream repo. Every linter hook is
`language: system` and calls the devShell binary directly, so tools are
versioned by nix, not per-hook. Check for a newer `rev` on
https://github.com/compilerla/conventional-pre-commit/releases and pin the
latest stable.

```yaml
repos:
  - repo: https://github.com/compilerla/conventional-pre-commit
    rev: v4.4.0
    hooks:
      - id: conventional-pre-commit
        stages: [commit-msg]

  - repo: local
    hooks:
      - id: gitleaks
        name: gitleaks (secrets)
        entry: gitleaks protect --staged
        language: system
        pass_filenames: false
      - id: nixfmt
        name: nixfmt (nix formatting)
        entry: nixfmt
        language: system
        files: \.nix$
      - id: editorconfig-checker
        name: editorconfig-checker
        entry: editorconfig-checker
        language: system
```

For every language detected, append its formatters and linters as local
`language: system` hooks (entry = the devShell binary, `files:` regex matching
the language's extensions) and add the tools to the devShell too. LSPs are
never hooked — they are editor-side and reach the editor through the
devShell `PATH`.

## .editorconfig

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
trim_trailing_whitespace = true

[*.nix]
indent_size = 2
```

## .gitignore

```gitignore
result
result-*
.direnv
.envrc
```

## Verify

After writing files, prove the scaffold works:

1. `nix flake check`
2. Install the pre-commit hooks:

```bash
nix develop --command pre-commit install --hook-type pre-commit --hook-type \
  commit-msg
```

3. `nix develop --command pre-commit run --all-files`

If any hook fails, fix the scaffold (usually the `.editorconfig` or formatting)
and re-run until clean. Report the final state to the user.

## Dendritic refactor (when the flake grows)

As soon as the flake gets complex — more than one `perSystem` feature beyond
the devShell, or roughly 80+ lines in `flake.nix` — refactor to the dendritic
pattern (https://github.com/mightyiam/dendritic): every non-entry-point Nix
file is a top-level flake-parts module implementing a single feature, imported
automatically, with module internals living under a `./nix` directory.

1. Move each per-system concern into its own module file under `nix/`, e.g.
  `nix/devshell.nix` (devShell + formatters/linters/LSPs + pre-commit hooks)
  and
  `nix/checks.nix` (anything new).
2. In `flake.nix`, replace the inline `perSystem` body with an automatic import
  of the module tree:

  ```nix
  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin"
      "aarch64-darwin" ];
      imports =
        map (f: ./nix/${f})
          (builtins.filter (f: builtins.match ".*\\.nix" f != null)
            (builtins.attrNames (builtins.readDir ./nix)));
    };
  ```

3. Each file stays a plain flake-parts module. A feature that must span files
  declares its own option in one module and sets it in another — same as the
  dendritic top-level-configuration pattern. Files are named for the feature
  they implement, not their type, and can be split/moved freely.
4. Re-run the Verify steps after the refactor; behavior must be unchanged.
