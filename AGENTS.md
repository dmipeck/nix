# AGENTS.md

## What this is

Generic, reusable NixOS + home-manager module library. No hosts, no
`nixosConfigurations` / `homeConfigurations` — only `nixosModules`,
`homeModules`, `vscodeModules`, `devShells`. Consumed by other
flakes. `CLAUDE.md` is a symlink to this file.

## Architecture (read this first)

- `flake.nix:14` is a flake-parts `mkFlake` over `inputs.import-tree ./nix`.
  **Every file under `nix/` is auto-imported as a flake-parts module**
  — nothing is wired by hand. To add a module, drop a file under the right
  subdir that returns `{ flake.<category>.<name> = ...; }`. Leading `_`
  in a filename (e.g. `_package.nix`) is skipped by import-tree.
- Contribution categories: `flake.homeModules.<name>`,
  `flake.nixosModules.<name>`,
  `flake.vscodeModules.<name>`. The public name is the option key, not the
  filename; one file may export several (e.g. `desktop/firefox.nix` exports
  `firefox` and `firefoxNixGL`).
- Shared flake-parts helpers live under `nix/lib/` and reach other
  flakeModules via `_module.args` (e.g. `nix/lib/sops.nix` → `sopsLib`,
  `nix/lib/skill-pack.nix` → `skillPackLib` for URL-agnostic skill-tree
  discovery/pack), same pattern as `mcpToolEnum` in `nix/dotagents/`.
- `systems = [ "x86_64-linux" ]` only (nix/devShells/default.nix:20).
- `nix/homeModules/desktop/` = GUI apps (nixGL-wrapped variants under
  `<app>NixGL`); top-level homeModules = tooling / AI stack / dev env.

## Commands

- `nix flake check` — CI gate (`.github/workflows/nix-check.yml`). **Caveat:**
  it lazily validates modules and overlays; it does **not** build homeModules,
  so broken references inside them pass. Exercise a module with
  `nix eval .#homeModules.<name>` or a scratch `homeManagerConfiguration`.
- `nix develop` — devShell (editorconfig-checker, gitleaks, nixfmt,
  pre-commit); shellHook installs git hooks (pre-commit + commit-msg
  stages). CI runs `nix develop --command pre-commit run --all-files`.
- Commit-msg hook enforces conventional commits; gitleaks,
  editorconfig-checker and nixfmt run pre-commit (nixfmt formats in
  place and fails the commit on changes). Format with `nixfmt` — pinned
  nixpkgs ships 1.4.0, which formats to the RFC 166 style
  (`nixfmt-rfc-style` is a deprecated alias of `nixfmt`). EditorConfig:
  2-space indent, LF for `*.nix`.

## AI-tools layering

- Local AI content — skills, agent (subagent) definitions and global rules —
  lives in the repo root `dotagents/` dir (Cursor Authoring Format layout:
  `dotagents/skills/<name>/SKILL.md`, flat `dotagents/agents/<name>.md`,
  `dotagents/rules/*.mdc` global rules with `alwaysApply`). There is no
  `commands/` layer: user-
  invoked (slash-only) workflows are skills with
  `disable-model-invocation: true` in SKILL.md frontmatter.
  `nix/dotagents/auto.nix` auto-discovers it with `builtins.readDir` — skill
  public name = directory name; agent public name = flat `.md` stem — and
  exposes skills as `config.dotagents.skills` (attrsOf package, layout
  `$out/skills/<name>/SKILL.md`), agents as
  `config.dotagents.commonModel.agents` (`{ frontmatter, body, path }` via
  Frontmatter Parser), plus `config.dotagents.skillLayouts` (attrsOf
  `"skill" | "collection"`, default `"skill"`) — per-key layout metadata
  telling adapters whether a skill key is a plain skill or a whole bundle.
  Legacy `config.dotagents.agents` (directory `agent.md` paths) is empty once
  all agents are Authoring Format.
  Auto values are `lib.mkOptionDefault` (priority 1500, same as
  an option default) so a profile can still override them;
  `config.dotagents.localPackages.whole-tree` is the whole content tree in one
  store path.
- `nix/dotagents/` is the flakeModule machinery for the AI-agent stack: the
  tool-enum + package option model (`nix/dotagents/dotagents.nix`),
  per-server tool enums / package bindings (`nix/dotagents/mcps/*.nix`),
  authored Cursor-shaped Server Definitions in `dotagents/mcp.json` (Common
  Model via `common-model.nix`), the local content auto-discovery
  (`nix/dotagents/auto.nix`), upstream skill collections
  (`nix/dotagents/skills/*.nix` — caveman, claude-plugins-official,
  grafana-skills, mattpocock-skills, skill-optimizer, stop-slop), and the
  global agent rules (`nix/dotagents/rules.nix`, Common Model from
  `dotagents/rules/*.mdc` via Frontmatter Parser).
  Auto-imported as flake-parts modules like everything else under `nix/`.
  The upstream skill modules emit `config.dotagents.skills` via `lib.genAttrs`
  over their exposed skill names; agents are flat Authoring Format files under
  `dotagents/agents/<id>.md`, not per-name nix modules. The `skills` option
  parent is a submodule with a `freeformType = attrsOf ...`, so
  auto-discovered and upstream-emitted keys share one type — there are no
  per-name option declarations. Skill keys with layout `"collection"`
  (grafana-core, grafana-lgtm, grafana-datasources, mcp-server-dev,
  skill-optimizer) are whole bundles whose `$out/skills/` holds many
  constituent skills, not a `$out/skills/<name>/SKILL.md` entry.
- `nix/homeModules/dotagents.nix` is the home-manager config layer: per-user
  `dotagents.mcps` options, the shared global context (defaulting to the
  Common Model `dotagents.rules` body), and MCP Instance overlay (enable,
  URL, sops, package resolve) onto authored `mcp.json` Server Definitions.
  Skill Sources (`dotagents.skillSources.<name>`: enable/src/root/layout,
  packed via `skillPackLib.packSkillSource`) and a Content Source stub
  (`dotagents.contentSources`, docs-only empty attrs) live in
  `nix/homeModules/_skill-sources.nix`. Adapter merge of Skill Source
  packages into the skill catalog is a separate cut. Add an instance
  option → edit `nix/homeModules/dotagents.nix`; add a Server Definition →
  edit `dotagents/mcp.json`; add tool enums → edit `nix/dotagents/mcps/`.
- `nix/homeModules/opencode.nix`, `claude.nix` and `cursor.nix` are thin
  adapters over the Common Model (`dotagents.commonModel.agents` from flat
  Authoring Format `agents/<id>.md`, plus skills/MCP/rules). Every skill
  becomes a `$out/skills/<name>` entry (opencode `skills`, claude `plugins`,
  cursor `~/.cursor/skills/<name>` — copy/symlink as authored); a collection
  key (layout `"collection"`) is a whole bundle — claude renders the package
  root as a plugin, opencode and cursor skip it (constituents are registered
  as separate keys already). Cursor Adapter Emit is passthrough: documented
  agent FM fields only (`name`/`description`/`model`/`readonly`/
  `is_background`), `metadata` stripped; no hand-tuned description or
  readonly lists. OpenCode/Claude convert from Common Model +
  `metadata.opencode` / `metadata.claude` (claude may still carry derived
  inline `mcpServers`). Skills with `disable-model-invocation: true` are
  slash-only (user-invoked); adapters pass that frontmatter through as-is.
  The github pair (`explore-github`, `github`) is registered only when
  `config.dotagents.mcps.github.enable` is set. Cursor
  passthrough-copies authored `dotagents/rules/*.mdc` to
  `~/.cursor/rules/` and writes MCP servers to `~/.cursor/mcp.json`.
  Claude still ships the external `set-budget` slash command from the
  statusline package; that is not part of the local `dotagents/` tree.
- Auto-pickup: to add a skill or agent, drop content into
  `dotagents/skills/<name>/SKILL.md` or flat `dotagents/agents/<name>.md` —
  every adapter picks it up on the next `home-manager switch`, with no nix
  edits. For a user-invoked (slash-only) skill, set
  `disable-model-invocation: true` in the SKILL.md frontmatter.

## VSCode special case

`nix/homeModules/desktop/vscode/default.nix` defines `flake.vscodeModules`
(sibling files like `go.nix` contribute `flake.vscodeModules.<name> =
pkgs: { extensions = ...; }`, consumed via `_module.args.vscodeModules`).
`nix flake check` prints "unknown flake output 'vscodeModules'" —
harmless noise.

## Secrets

- Consistent per-module sops contract (`sopsLib` from `nix/lib/sops.nix`,
  injected into flakeModules via `_module.args.sopsLib`):
  `<module>.sops.enable` gates wiring; then
  `<module>.sops.secrets.<program-key-name>.key = "<sops-key-name>"` and
  optionally `.keyFile` for a path override. Examples:
  `comin.sops.secrets.accessToken`,
  `dotagents.mcps.grafana.sops.secrets.serviceAccountToken`,
  `dotagents.mcps.*.sops.secrets.token`. Decrypted at runtime; the value is
  only ever pointed to by file path (`GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE`),
  never inlined. Never inline tokens in module code; gitleaks enforces this.
- `.envrc` is `use flake` (direnv).
