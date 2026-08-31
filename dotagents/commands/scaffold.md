---
description: Scaffold a new project with a flake-parts flake.nix, a Nix
  devShell full of linters, and pre-commit wired to run them all.
---

Scaffold a new software project in the current directory. If the directory is
not already a git repo, run `git init` first (pre-commit requires it).

## Discover languages and linters

Before scaffolding, determine what the project actually is:

1. **Explore the repo** — glob for source files and manifests (e.g. `*.go`,
  `*.rs`, `package.json`, `go.mod`, `Cargo.toml`,
  `*.ts`, `*.tsx`, `*.js`, `*.rb`, etc.) to identify the languages in use.
  Check existing config like `.golangci.yml`, `.eslintrc*`, or build
  definitions for hints about already-intended tooling. Empty or nearly
  empty dir means the project is new — infer the intended language from the
  directory name and any README.
2. **Search the web** — for each language found, look up the current standard
  linter/formatter (e.g. Go: golangci-lint, gofmt/goimports; Rust: clippy,
  rustfmt; Python: ruff; TypeScript/JS: eslint, prettier, biome; Ruby:
  rubocop; shell: shellcheck). Prefer the tool that is the community default
  for that language in 2026, and note the exact nixpkgs package name and the
  pre-commit hook id/repo that wraps it. Skip deprecated or niche tools.
3. Ask the user for the project name if not obvious from the directory; confirm
  the detected language set and the linter list before writing files, but
  proceed with sensible defaults if the user has no preference.

"Other relevant linters" below always means the linters discovered here plus
the Nix tooling. Do not invent a language's linter from memory — verify it
exists in nixpkgs (e.g. `nix search nixpkgs <tool>`) and that its pre-commit
hook id is real before including it.

## What to create

1. `flake.nix` — flake-parts based. A `devShells.default` that installs
  pre-commit, gitleaks, nixfmt, editorconfig-checker, plus any
  language-relevant linters. The shell hook installs the pre-commit git hooks.
2. `.pre-commit-config.yaml` — a `conventional-commits` hook plus one hook per
  linter, using the binaries from the devShell (`language: system`).
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
          linters = with pkgs; [
            pre-commit
            gitleaks
            nixfmt
            editorconfig-checker
          ];
        in
        {
          devShells.default = pkgs.mkShell {
            packages = linters;
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

For every language discovered above, append its linters as local
`language: system` hooks and add their binaries to the devShell too.

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
  `nix/devshell.nix` (devShell + linters + pre-commit hooks) and
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
