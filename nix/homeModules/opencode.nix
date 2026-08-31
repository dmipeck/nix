{ config, ... }@flakeArgs:
let
  # Skill/plugin packages are owned by nix/dotagents/ (skills/*.nix). `config`
  # here is flake-parts state (auto-imported under nix/); captured once so the
  # home-manager module below can reference the packages.
  agentSkills = flakeArgs.config.dotagents.skills;
  agents = flakeArgs.config.dotagents.agents;
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

      # All agent definitions (dotagents/agents/<name>/agent.md), registered
      # unconditionally except the github pair (see the `agents` config below).
      allAgents = lib.mapAttrs (_: p: p) agents;
      githubAgentNames = [
        "explore-github"
        "github"
      ];

      # opencode namespaces every MCP tool as `<server>_<tool>`. By default the
      # whole MCP set is denied for every session (via the top-level `tools`
      # map below), so the schemas of all those tools never enter the main
      # session's context. A subagent that needs a server opts back in with
      # `tools: { "<server>_*": true }` in its agent definition — the
      # documented "enable per agent, disable globally" MCP pattern.
      deniedMcpTools = lib.genAttrs (map (name: "${name}_*") (lib.attrNames mcpServers)) (_: false);

      # A local stdio server (command array + optional env) or a remote HTTP
      # server, matching the v1 `mcp` shape opencode's home-manager module and
      # settings.mcp expect.
      toMcp =
        name: srv:
        if srv.type == "remote" then
          {
            type = "remote";
            url = srv.url;
          }
          // lib.optionalAttrs (srv.headers != { }) { inherit (srv) headers; }
        else
          {
            type = "local";
            command = [ srv.command ] ++ srv.args;
          }
          // lib.optionalAttrs (srv.env != { }) { environment = srv.env; };

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
      # skill into dotagents/skills/ needs no adapter edit.
      skills = lib.mapAttrs' (name: pkg: lib.nameValuePair name "${pkg}/skills/${name}") agentSkills;

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
      options.opencode.enable = lib.mkEnableOption "Enable opencode AI coding agent";

      options.opencode.experimental.workspaces = {
        enable = lib.mkEnableOption ''
          the experimental opencode workspaces feature (`/warp`, `/workspaces`).
          Wraps the opencode binary with `OPENCODE_EXPERIMENTAL_WORKSPACES=1`.
        '';
      };

      config = lib.mkIf config.opencode.enable {
        programs.opencode.enable = true;

        # Workspaces is env-var gated; enable it by wrapping the binary.
        programs.opencode.package = lib.mkIf config.opencode.experimental.workspaces.enable wrappedOpencode;

        # Global context written to ~/.config/opencode/AGENTS.md, applied
        # across every opencode session. Content lives once in
        # config.dotagents.context (dotagents.nix), shared with Claude Code.
        programs.opencode.context = config.dotagents.context;

        programs.opencode.skills = skills;

        # Delegate-to-subagent skills (commit, test, nix) reference their
        # subagent by name; the definitions come from dotagents/agents/<name>/agent.md
        # via config.dotagents.agents (auto-discovered in nix/dotagents/auto.nix).
        # nix re-enables the nixos MCP tools via `tools` in its agent definition.
        # orchestrate is a primary agent (mode: primary) that has no tools of its
        # own and delegates everything through `task`; it is the default agent.
        # explore-github and github re-enable the github MCP tools via `tools`
        # in their agent definitions. Both only speak the github server, so
        # they're registered only when the per-user github instance is enabled.
        # explore-git and git talk to the local repo through bash `git`
        # commands, so they're always registered.
        programs.opencode.agents =
          (lib.removeAttrs allAgents githubAgentNames)
          // lib.optionalAttrs config.dotagents.mcps.github.enable (
            lib.genAttrs githubAgentNames (n: allAgents.${n})
          );

        # Custom slash commands, e.g. scaffold (built by dmipeck/agents
        # from commands/scaffold.md, passed through config.dotagents.commands).
        # home-manager maps each name to opencode/commands/<name>.md — but its
        # commands option only routes `lib.isPath` values to `source`; a
        # derivation (the command package) lands in `text` and fails the string
        # type check. Derivation-backed commands are therefore wired through
        # xdg.configFile directly (its `source` accepts derivations, same as
        # claude-code's mkSourceEntry), while plain text/path commands keep the
        # normal programs.opencode.commands path.
        programs.opencode.commands = lib.filterAttrs (_: c: !lib.isDerivation c) config.dotagents.commands;

        xdg.configFile =
          lib.mkIf (lib.filterAttrs (_: c: lib.isDerivation c) config.dotagents.commands != { })
            (
              lib.mapAttrs' (name: drv: lib.nameValuePair "opencode/commands/${name}.md" { source = drv; }) (
                lib.filterAttrs (_: c: lib.isDerivation c) config.dotagents.commands
              )
            );

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

          # The orchestrate (a primary agent) is the default when opencode
          # starts, so every session routes through delegation.
          default_agent = "orchestrate";

          # MCP servers stay registered (`mcp` above) but their tools are
          # denied for every session by default, keeping their schemas out of
          # the main context. Subagents re-enable servers per-agent later.
          tools = deniedMcpTools;

          # Enable LSP servers and formatters. Both are disabled by default;
          # `true` turns on every built-in server/formatter, starting one when a
          # matching file extension is opened and the required command is found.
          lsp = true;
          formatter = true;

          permission = {
            bash = {
              "awk *" = "deny";
              "sed *" = "deny";
              "kubectl *" = "deny";
            };
            external_directory = {
              "/nix/store/**" = "allow";
              "~/.config/**" = "allow";
            };
          };
        };
      };
    };
}
