# AGENTS.md

## What this is

Generic, reusable NixOS + home-manager module library. No hosts, no
`nixosConfigurations` / `homeConfigurations` — only `nixosModules`,
`homeModules`, `vscodeModules`, `devShells`. Consumed by other
flakes. `CLAUDE.md` is a symlink to this file.

## Architecture (read this first)

- `flake.nix:14` is a flake-parts `mkFlake` over `inputs.import-tree ./nix`.
  **Every file under `nix/` is auto-imported as a flake-parts module** — nothing
  is wired by hand. To add a module, drop a file under the right subdir that
  returns `{ flake.<category>.<name> = ...; }`.
- Contribution categories: `flake.homeModules.<name>`,
  `flake.nixosModules.<name>`,
  `flake.vscodeModules.<name>`. The public name is the option key, not the
  filename; one file may export several (e.g. `desktop/firefox.nix` exports
  `firefox` and `firefoxNixGL`).
- `systems = [ "x86_64-linux" ]` only (nix/devShells/default.nix:20).
- `nix/homeModules/desktop/` = GUI apps (nixGL-wrapped variants under
  `<app>NixGL`); top-level homeModules = tooling / AI stack / dev env.

## Commands

- `nix flake check` — CI gate (`.github/workflows/nix-check.yml`). **Caveat:**
  it lazily validates modules and overlays; it does **not** build homeModules,
  so broken references inside them pass. Exercise a module with
  `nix eval .#homeModules.<name>` or a scratch `homeManagerConfiguration`.
- `nix develop` — devShell (editorconfig-checker, gitleaks, nixfmt, pre-commit);
  shellHook installs git hooks (pre-commit + commit-msg stages). CI runs
  `nix develop --command pre-commit run --all-files`.
- Commit-msg hook enforces conventional commits; gitleaks, editorconfig-checker
  and nixfmt run pre-commit (nixfmt formats in place and fails the commit on
  changes). Format with `nixfmt` — pinned nixpkgs ships 1.4.0, which formats to
  the RFC 166 style (`nixfmt-rfc-style` is a deprecated alias of `nixfmt`).
  EditorConfig: 2-space indent, LF for `*.nix`.

## AI-tools layering

- Local AI content — skills, commands, agent (subagent) definitions and global
  rules — lives in the repo root `dotagents/` dir (`.agents` protocol layout:
  `dotagents/skills/<name>/SKILL.md`, `dotagents/commands/<file>.md`,
  `dotagents/agents/<name>/agent.md`, `dotagents/agents.md` global rules).
  `nix/dotagents/local.nix` packages it into derivations (`dotagents.localPackages`):
  bare-dir skill packages (`git-workflow`, `thrifty`,
  `conventional-commits`, `comments`), the whole-tree `dotagents` package
  (skills + commands + agents, sliced by the adapters via `$out/skills/<name>` /
  `$out/agents/<name>/agent.md`), and the `scaffold` command file.
- `nix/dotagents/` is the flakeModule machinery for the AI-agent stack: the
  neutral `dotagents.mcpServers` option model (`nix/dotagents/dotagents.nix`),
  per-server configs (`nix/dotagents/mcps/*.nix`), upstream skill/plugin
  derivations (`nix/dotagents/skills/*.nix`), and the global agent rules
  (`nix/dotagents/rules.nix`, read from `dotagents/agents.md`).
  Auto-imported as flake-parts modules like everything else under `nix/`.
  The local skill/command packages referenced by `nix/dotagents/skills/*.nix` and
  `nix/dotagents/commands/*.nix` are built from `dotagents/` by `nix/dotagents/local.nix`.
  The golang/postgres skills live inside the whole-tree `dotagents` package
  (`nix/dotagents/skills/golang.nix`), so the adapters slice them out via
  `$out/skills/<name>`.
- `nix/homeModules/dotagents.nix` is the home-manager config layer: per-user
  `dotagents.instance` options, the shared global context (defaulting to the
  `dotagents.rules` content from `dotagents/agents.md`), and the overlay of
  instance values (grafana URL/token file, gitlab URL) onto the shared MCP
  server definitions. It reads `config.dotagents.mcpServers`,
  `config.dotagents.rules` and `config.dotagents.commands` from the auto-imported
  `nix/dotagents/` modules.
  Add an instance option → edit dotagents.nix; add a server, skill or command →
  edit nix/dotagents/ (content goes in `dotagents/`).
- `opencode.nix` renders permission allow/ask lists from
  `mcpServers.<srv>.readOnlyTools/writableTools`; `claude.nix` remaps them to
  the `mpc__plugin_hm_<server>__<tool>` namespace.

## VSCode special case

`nix/homeModules/desktop/vscode/default.nix` defines `flake.vscodeModules`
(sibling files like `go.nix` contribute `flake.vscodeModules.<name> =
pkgs: { extensions = ...; }`, consumed via `_module.args.vscodeModules`).
`nix flake check` prints "unknown flake output 'vscodeModules'" — harmless noise.

## Secrets

- sops-nix convention everywhere: secrets are referenced by name
  (`dotagents.instance.*.tokenSopsKey`, `comin.accessTokenSopsKey`) and decrypted
  at runtime; the value is only ever pointed to by file path
  (`GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE`), never inlined. Never
  inline tokens in module code; gitleaks enforces this.
- `.envrc` is `use flake` (direnv).
