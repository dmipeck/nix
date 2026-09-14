{ config, adapterEmit, ... }@flakeArgs:
let
  # Skill/plugin packages are owned by nix/dotagents/ (skills/*.nix). `config`
  # here is flake-parts state (auto-imported under nix/); captured once so the
  # home-manager module below can reference the packages.
  agentSkills = flakeArgs.config.dotagents.skills;
  skillLayouts = flakeArgs.config.dotagents.skillLayouts;
  # Common Model agents (flat Authoring Format); OpenCode Adapter Emit converts.
  commonAgents = flakeArgs.config.dotagents.commonModel.agents;
  cheapSubagents = flakeArgs.config.dotagents.cheapSubagents;
  # Per-client default model + variation (dotagents/models), driven by the
  # config.dotagents.models option; this adapter reads the `opencode` client.
  models = flakeArgs.config.dotagents.models.opencode;
in
{
  flake.homeModules.opencode =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      # Neutral MCP server configs + per-user instance options live in
      # homeModules/dotagents.nix; skill packages come from nix/dotagents/
      # (`agentSkills`, captured above). This module is a thin adapter that
      # maps them onto opencode's config dialect and renders opencode's
      # permission rules from the shared per-server tool lists.
      mcpServers = config.dotagents.mcpServers;

      # All agents: Common Model → Adapter Emit convert (hoist metadata.opencode,
      # inject model/variant from Nix when the file omits them). Registered
      # conditionally: the github pair, argocd and the gitlab pair need their
      # per-user MCP server present; everything else is unconditional (see
      # `opencodeAgents` below). Authored metadata.opencode.model / .variant win.
      renderCommonAgent =
        name: agent:
        let
          cheap = lib.elem name cheapSubagents;
          model =
            if cheap then
              models.subagent.model
            else if name == "orchestrate" then
              models.primary.model
            else
              null;
          variation =
            if cheap then
              models.subagent.variation
            else if name == "orchestrate" then
              models.primary.variation
            else
              null;
          text = adapterEmit.emitOpenCodeAgent agent {
            inherit model;
            variant = variation;
          };
        in
        pkgs.writeText "dotagents-${name}-agent-opencode" text;

      allAgents = lib.mapAttrs renderCommonAgent commonAgents;

      # Registered agent set: the same conditional composition as before (github
      # pair / argocd / gitlab gating), over `allAgents`. plane is a write-only
      # agent gated on `dotagents.mcps.plane.enable` whose spawning asks first.
      # firebase is a read/write pair gated on `dotagents.mcps.firebase.enable`;
      # spawning the write-capable firebase agent asks first.
      opencodeAgents =
        (lib.removeAttrs allAgents (
          githubAgentNames
          ++ gitlabAgentNames
          ++ argocdAgentNames
          ++ cloudflareAgentNames
          ++ cloudflareBindingsAgentNames
          ++ cloudflareObservabilityAgentNames
          ++ planeAgentNames
          ++ firebaseAgentNames
        ))
        // lib.optionalAttrs config.dotagents.mcps.github.enable (
          lib.genAttrs githubAgentNames (n: allAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.argocd.enable (
          lib.genAttrs argocdAgentNames (n: allAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.gitlab.enable (
          lib.genAttrs gitlabAgentNames (n: allAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.cloudflare.enable (
          lib.genAttrs cloudflareAgentNames (n: allAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.cloudflare.bindings.enable (
          lib.genAttrs cloudflareBindingsAgentNames (n: allAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.cloudflare.observability.enable (
          lib.genAttrs cloudflareObservabilityAgentNames (n: allAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.plane.enable (
          lib.genAttrs planeAgentNames (n: allAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.firebase.enable (
          lib.genAttrs firebaseAgentNames (n: allAgents.${n})
        );

      # Adapter Emit produces writeText derivations. opencode's home-manager
      # module only accepts path-valued agents as `source`; derivations fail
      # the string type check on `text`. Write every agent via xdg.configFile
      # (its `source` accepts derivations).
      agentFiles = lib.mapAttrs' (
        name: drv: lib.nameValuePair "opencode/agents/${name}.md" { source = drv; }
      ) opencodeAgents;
      githubAgentNames = [
        "explore-github"
        "github"
      ];
      gitlabAgentNames = [
        "explore-gitlab"
        "gitlab"
      ];
      argocdAgentNames = [
        "explore-argocd"
      ];
      cloudflareAgentNames = [
        "explore-cloudflare"
        "cloudflare"
      ];
      cloudflareBindingsAgentNames = [
        "explore-cloudflare-bindings"
        "cloudflare-bindings"
      ];
      cloudflareObservabilityAgentNames = [
        "explore-cloudflare-observability"
      ];
      planeAgentNames = [
        "plane"
      ];
      firebaseAgentNames = [
        "explore-firebase"
        "firebase"
      ];

      # opencode namespaces every MCP tool as `<server>_<tool>`. By default the
      # whole MCP set is denied for every session (via the top-level `tools`
      # map below), so the schemas of all those tools never enter the main
      # session's context. A subagent that needs a server opts back in with
      # `tools: { "<server>_*": true }` in its agent definition — the
      # documented "enable per agent, disable globally" MCP pattern.
      deniedMcpTools = lib.genAttrs (map (name: "${name}_*") (lib.attrNames mcpServers)) (_: false);

      # Cursor-shaped Common Model → OpenCode v1 mcp dialect (local/remote).
      # Secrets keep "{file:...}" substitution; Cursor rewrite is Cursor-only.
      toMcp =
        _name: srv:
        if (srv.type or null) == "stdio" || (srv ? command) then
          {
            type = "local";
            command = [ srv.command ] ++ (srv.args or [ ]);
          }
          // lib.optionalAttrs ((srv.env or { }) != { }) { environment = srv.env; }
        else
          {
            type = "remote";
            url = srv.url;
          }
          // lib.optionalAttrs ((srv.headers or { }) != { }) { inherit (srv) headers; }
          // lib.optionalAttrs (srv ? auth && srv.auth != { }) {
            oauth =
              lib.optionalAttrs (srv.auth ? CLIENT_ID) { clientId = srv.auth.CLIENT_ID; }
              // lib.optionalAttrs (srv.auth ? CLIENT_SECRET) {
                clientSecret = srv.auth.CLIENT_SECRET;
              }
              // lib.optionalAttrs (srv.auth ? scopes) {
                scope = lib.concatStringsSep " " srv.auth.scopes;
              };
          };

      mcp = lib.mapAttrs toMcp mcpServers;

      # The workspaces feature (`/warp`, `/workspaces`) is env-var gated by
      # OPENCODE_EXPERIMENTAL_WORKSPACES. Wrap the default binary with the var
      # set so the flag is on for both the TUI and the server it spawns.
      # home-manager reads package.meta/version to wire tui.json and the web
      # service, so both are preserved on the wrapper.
      wrappedOpencode = pkgs.symlinkJoin {
        name = "opencode-workspaces-${pkgs.opencode.version}";
        paths = [ pkgs.opencode ];
        inherit (pkgs.opencode) meta version;
        preferLocalBuild = true;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/opencode --set OPENCODE_EXPERIMENTAL_WORKSPACES 1
        '';
      };

      # Skill/plugin packages expose $out/skills/<name>/SKILL.md; opencode
      # wants each skill referenced by its directory path. The whole
      # config.dotagents.skills attrset (local auto-discovered skills + every
      # upstream skill package) is rendered generically, so dropping a new
      # skill into dotagents/skills/ needs no adapter edit. Collection keys
      # (whole bundles whose $out/skills/ holds many constituent skills) are
      # skipped: opencode has no single-skill form for them, and their
      # constituents are already registered as separate keys.
      skills = lib.mapAttrs' (name: pkg: lib.nameValuePair name "${pkg}/skills/${name}") (
        lib.filterAttrs (name: _: (skillLayouts.${name} or "skill") != "collection") agentSkills
      );

      # Both themes share the opencode theme schema and mapping; only the
      # `defs` palette differs.
      themeSchema = "https://opencode.ai/theme.json";
      themeMapping = {
        primary = "keyword";
        secondary = "class";
        accent = "literal";
        error = "deleted";
        warning = "builtin";
        success = "keyword";
        info = "class";
        text = "foreground";
        textMuted = "muted";
        background = "background";
        backgroundPanel = "panel";
        backgroundElement = "panel";
        border = "border";
        borderActive = "border_active";
        borderSubtle = "border";
        diffAdded = "keyword";
        diffRemoved = "deleted";
        diffContext = "comment";
        diffHunkHeader = "comment";
        diffHighlightAdded = "function";
        diffHighlightRemoved = "string";
        diffAddedBg = "diffAddedBg";
        diffRemovedBg = "diffRemovedBg";
        diffContextBg = "panel";
        diffLineNumber = "punctuation";
        diffAddedLineNumberBg = "diffAddedBg";
        diffRemovedLineNumberBg = "diffRemovedBg";
        markdownText = "foreground";
        markdownHeading = "keyword";
        markdownLink = "class";
        markdownLinkText = "literal";
        markdownCode = "string";
        markdownBlockQuote = "comment";
        markdownEmph = "property";
        markdownStrong = "builtin";
        markdownHorizontalRule = "punctuation";
        markdownListItem = "keyword";
        markdownListEnumeration = "literal";
        markdownImage = "class";
        markdownImageText = "literal";
        markdownCodeBlock = "foreground";
        syntaxComment = "comment";
        syntaxKeyword = "keyword";
        syntaxFunction = "function";
        syntaxVariable = "variable";
        syntaxString = "string";
        syntaxNumber = "number";
        syntaxType = "class";
        syntaxOperator = "keyword";
        syntaxPunctuation = "punctuation";
      };
    in
    {
      options.opencode.experimental.workspaces = {
        enable = lib.mkEnableOption ''
          the experimental opencode workspaces feature (`/warp`, `/workspaces`).
          Wraps the opencode binary with `OPENCODE_EXPERIMENTAL_WORKSPACES=1`.
        '';
      };

      config = {
        programs.opencode.enable = true;

        # Workspaces is env-var gated; enable it by wrapping the binary.
        programs.opencode.package = lib.mkIf config.opencode.experimental.workspaces.enable wrappedOpencode;

        # Global context written to ~/.config/opencode/AGENTS.md, applied
        # across every opencode session. Content lives once in
        # config.dotagents.context (dotagents.nix), shared with Claude Code.
        programs.opencode.context = config.dotagents.context;

        programs.opencode.skills = skills;

        # Delegate-to-subagent skills (commit, test, nix) reference their
        # subagent by name; definitions come from Common Model agents via
        # Adapter Emit (flat Authoring Format under dotagents/agents/<id>.md).
        # explore-nix re-enables the nixos MCP tools via `tools` in its agent
        # definition; nix is the write/apply agent, scoped to state-changing
        # command families via its bash permission map.
        # orchestrate is a primary agent (mode: primary) that has no tools of its
        # own and delegates everything through `task`; it is the default agent.
        # explore-github and github re-enable the github MCP tools via `tools`
        # in their agent definitions — explore-github with an explicit
        # read-only allowlist (the github server also registers write tools),
        # github with the whole server — and are registered only when the
        # per-user github instance (`dotagents.mcps.github.enable`) is
        # enabled. Spawning github asks first (permission.task on orchestrate).
        # explore-argocd re-enables the argocd MCP tools via `tools` in its agent
        # definition and is registered only when the per-user argocd instance is
        # enabled.
        # explore-gitlab and gitlab re-enable the gitlab MCP tools via `tools`
        # in their agent definitions — explore-gitlab with an explicit
        # read-only allowlist, gitlab with the whole server — and are
        # registered only when the per-user gitlab instance
        # (`dotagents.mcps.gitlab.enable`) is enabled. Spawning gitlab asks
        # first (permission.task on orchestrate).
        # explore-git and git talk to the local repo through bash `git`
        # commands, so they're always registered.
        # Agents are writeText derivations → xdg.configFile (not
        # programs.opencode.agents, which only accepts paths).
        # User-invoked workflows live as skills with
        # `disable-model-invocation: true` — no separate commands layer.
        xdg.configFile = lib.mkIf (agentFiles != { }) agentFiles;

        programs.opencode.themes = {
          vitesse-dark = {
            "$schema" = themeSchema;
            defs = {
              foreground = "#d4cfbf";
              background = "#1e1e1e";
              comment = "#758575";
              string = "#d48372";
              literal = "#429988";
              keyword = "#4d9375";
              function = "#a1b567";
              deleted = "#a14f55";
              class = "#54b1bf";
              builtin = "#e0a569";
              property = "#dd8e6e";
              namespace = "#db889a";
              punctuation = "#858585";
              decorator = "#bd8f8f";
              number = "#6394bf";
              boolean = "#1c6b48";
              variable = "#c2b36e";
              regex = "#ab5e3f";
              panel = "#252525";
              border = "#3a3a3a";
              border_active = "#4d9375";
              muted = "#6e6e6e";
              diffAddedBg = "#2a3a2a";
              diffRemovedBg = "#3a2a2a";
            };
            theme = themeMapping;
          };

          # Minimal dark theme, defined in Nix.
          # Warm low-blue-light palette: dark warm background, warm foreground,
          # hues at or below green energy (ROYG), no blue/indigo/violet.
          royg = {
            "$schema" = themeSchema;
            defs = {
              foreground = "#d4cfbf";
              background = "#1c1917";
              comment = "#758575";
              string = "#d48372";
              literal = "#d19a66";
              keyword = "#4d9375";
              function = "#e5c07b";
              deleted = "#a14f55";
              class = "#98c379";
              builtin = "#d19a66";
              property = "#d19a66";
              namespace = "#e5c07b";
              punctuation = "#8a8578";
              decorator = "#bd8f8f";
              number = "#d19a66";
              boolean = "#4d9375";
              variable = "#c2b36e";
              regex = "#ab5e3f";
              panel = "#28241f";
              border = "#413c35";
              border_active = "#4d9375";
              muted = "#6f6a60";
              diffAddedBg = "#2a3a2a";
              diffRemovedBg = "#3a2a2a";
            };
            theme = themeMapping // {
              primary = "class";
              secondary = "keyword";
            };
          };
        };

        programs.opencode.tui.theme = "royg";

        programs.opencode.settings = {
          mcp = mcp;

          # Default model for every session (config.dotagents.models.opencode.
          # primary). mkDefault so a consuming host (e.g. nix-private per-user
          # config) can pin its own without a module-system conflict. The
          # primary variation is carried by the rendered orchestrate agent
          # frontmatter (`variant:`), since opencode has no top-level variant.
          model = lib.mkDefault models.primary.model;

          # The orchestrate (a primary agent) is the default when opencode
          # starts, so every session routes through delegation.
          default_agent = "orchestrate";

          # opencode's built-in `general` subagent stays available as a
          # last-resort generic fallback: orchestrate prefers purpose-built
          # subagents and falls back to `general` only when nothing else fits
          # (policy lives in orchestrate's agent file), spawning it prompts
          # the user (permission.task there), and `general`'s own write tools
          # ask before running.
          agent = {
            general = {
              description = "Generic fallback subagent. Use only when no purpose-built subagent is suited to the task.";
              permission = {
                bash = "ask";
                edit = "ask";
              };
            };
            # The built-in explorer runs on the subagent model + variation.
            explore = {
              model = models.subagent.model;
            }
            // lib.optionalAttrs (models.subagent.variation != null) {
              variant = models.subagent.variation;
            };
          };

          # MCP servers stay registered (`mcp` above) but their tools are
          # denied for every session by default, keeping their schemas out of
          # the main context. Subagents re-enable servers per-agent later.
          tools = deniedMcpTools;

          # Enable LSP servers and formatters. Both are disabled by default;
          # `true` turns on every built-in server/formatter, starting one when a
          # matching file extension is opened and the required command is found.
          lsp = true;
          formatter = true;

          # The github and gitlab MCP servers' tools are denied by default
          # (tools map above); orchestrate asks before spawning the
          # write-capable github/gitlab subagent (permission.task). The
          # glab/gh CLIs stay installed for human shell use; orchestrate
          # already denies all bash in its own agent file, so they need no
          # top-level deny here and every Bash-capable agent may use them.
          # sops stays denied at the top level because agents have no need
          # to decrypt secrets; sops-nix already hands them the decrypted
          # file paths, so a top-level deny is the simplest gate.
          # The write-capable cloudflare and cloudflare-bindings subagents
          # ask first too (permission.task); the read-only
          # cloudflare-observability subagent needs no gate. The wrangler
          # CLI is deliberately not denied here: the cloudflare agents never
          # reach bash (their own agent files deny all bash), so a top-level
          # deny would be dead weight.
          permission = {
            task = {
              github = "ask";
              gitlab = "ask";
              cloudflare = "ask";
              cloudflare-bindings = "ask";
              plane = "ask";
              firebase = "ask";
            };
            bash = {
              "awk *" = "deny";
              "sed *" = "deny";
              "kubectl *" = "deny";
              "sops *" = "deny";
            };
            external_directory = {
              # Read-only window into the tool config trees that other agent
              # tooling (claude / opencode / dotagents) manages, plus the
              # generated opencode config. Grants the external-directory gate
              # only; writes still need an `edit` rule, so nothing here is
              # writeable by agents. Scope is deliberately narrow: only the
              # opencode subtree of ~/.config, and only the content dirs of
              # ~/.claude (never its root, which holds .credentials.json and
              # session history).
              "/nix/store/**" = "allow";
              "~/.agents/**" = "allow";
              "~/.claude/agents/**" = "allow";
              "~/.claude/commands/**" = "allow";
              "~/.claude/skills/**" = "allow";
              "~/.config/opencode/**" = "allow";
              "~/.opencode/**" = "allow";
            };
          };
        };
      };
    };
}
