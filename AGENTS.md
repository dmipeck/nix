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
  `nix/dotagents/auto.nix` auto-discovers it with `builtins.readDir` — the
  public name is the directory name (skills/agents) or the filename minus
  `.md` (commands), no index files — and exposes it as three options with
  uniform contracts: `config.dotagents.skills` (attrsOf package, layout
  `$out/skills/<name>/SKILL.md`), `config.dotagents.agents` (attrsOf path to
  `agent.md`), `config.dotagents.commands` (attrsOf package, `$out` = the
  command file). Auto values are `lib.mkOptionDefault` (priority 1500, same as
  an option default) so a profile can still override them;
  `config.dotagents.localPackages.whole-tree` is the whole content tree in one
  store path.
- `nix/dotagents/` is the flakeModule machinery for the AI-agent stack: the
  neutral `dotagents.mcpServers` option model (`nix/dotagents/dotagents.nix`),
  per-server configs (`nix/dotagents/mcps/*.nix`), the local content
  auto-discovery (`nix/dotagents/auto.nix`), upstream skill collections
  (`nix/dotagents/skills/*.nix` — caveman, claude-plugins-official,
  grafana-skills, mattpocock-skills, skill-optimizer, stop-slop), and the
  global agent rules (`nix/dotagents/rules.nix`, read from `dotagents/agents.md`).
  Auto-imported as flake-parts modules like everything else under `nix/`.
  The upstream skill modules emit `config.dotagents.skills` via `lib.genAttrs`
  over their exposed skill names; agent definitions are the auto-discovered
  `dotagents/agents/<name>/agent.md` files, not per-name nix modules. The
  `skills`/`agents`/`commands` option parents are submodules with a
  `freeformType = attrsOf ...`, so auto-discovered and upstream-emitted keys
  share one type — there are no per-name option declarations.
- `nix/homeModules/dotagents.nix` is the home-manager config layer: per-user
  `dotagents.mcps` options, the shared global context (defaulting to the
  `dotagents.rules` content from `dotagents/agents.md`), and the overlay of
  instance values (grafana URL/token file, gitlab URL) onto the shared MCP
  server definitions. It reads `config.dotagents.mcpServers`,
  `config.dotagents.rules` and `config.dotagents.commands` from the auto-imported
  `nix/dotagents/` modules.
  Add an instance option → edit `nix/homeModules/dotagents.nix`; add a server →
  edit `nix/dotagents/mcps/`.
- `nix/homeModules/opencode.nix` and `claude.nix` are thin adapters: each
  iterates `config.dotagents.skills`, `config.dotagents.agents` and
  `config.dotagents.commands` generically and maps them onto the tool's config
  dialect. Every skill becomes a `$out/skills/<name>` entry (opencode `skills`,
  claude `plugins`); every agent is rendered from its `agent.md` — opencode
  passes the files through, claude re-renders them with a generic renderer plus
  a per-agent override map (e.g. `nix`, `explore-github` and `github` carry
  inline `mcpServers` blocks); commands pass straight through to each tool's
  custom-command set. The github pair (`explore-github`, `github`) is
  registered only when `config.dotagents.mcps.github.enable` is set.
- Auto-pickup: to add a skill, agent or command, just drop the content into
  `dotagents/skills/<name>/SKILL.md`, `dotagents/agents/<name>/agent.md` or
  `dotagents/commands/<file>.md` — both tools pick it up on the next
  `home-manager switch`, with no nix edits.

## VSCode special case

`nix/homeModules/desktop/vscode/default.nix` defines `flake.vscodeModules`
(sibling files like `go.nix` contribute `flake.vscodeModules.<name> =
pkgs: { extensions = ...; }`, consumed via `_module.args.vscodeModules`).
`nix flake check` prints "unknown flake output 'vscodeModules'" — harmless noise.

## Secrets

- sops-nix convention everywhere: secrets are referenced by name
  (`dotagents.mcps.*.tokenSopsKey`, `comin.accessTokenSopsKey`) and decrypted
  at runtime; the value is only ever pointed to by file path
  (`GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE`), never inlined. Never
  inline tokens in module code; gitleaks enforces this.
- `.envrc` is `use flake` (direnv).
