{

  flake.homeModules.opencode =
    {
      lib,
      config,
      ...
    }:
    let
      # Neutral MCP servers + skill packages + per-user instance options live
      # in modules/homeModules/agents.nix; this module is a thin adapter that
      # maps them onto opencode's config dialect and renders opencode's
      # permission rules from the shared per-server tool lists.
      mcpServers = config.agents.mcpServers;

      # opencode namespaces every MCP tool as `<server>_<tool>`. It allows
      # everything by default, so the allow-lists are explicit defence-in-depth
      # on top of the read-only MCP servers (grafana); the gitlab write
      # tools (which claude prompts on) and the bash denies preserve claude's
      # "prompt on anything not explicitly allowed" behaviour in opencode's
      # permissive model.
      allowedMcpTools = lib.concatLists (
        lib.mapAttrsToList (name: srv: map (tool: "${name}_${tool}") srv.readOnlyTools) mcpServers
      );
      askMcpTools = lib.concatLists (
        lib.mapAttrsToList (name: srv: map (tool: "${name}_${tool}") srv.writableTools) mcpServers
      );

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

      # Skill/plugin packages expose $out/skills/<name>/SKILL.md; opencode
      # wants each skill referenced by its directory path.
      skills = lib.mapAttrs' (name: pkg: lib.nameValuePair name "${pkg}/skills/${name}") {
        "build-mcp-app" = config.agents.skills.mcp-server-dev;
        "build-mcpb" = config.agents.skills.mcp-server-dev;
        "build-mcp-server" = config.agents.skills.mcp-server-dev;
        "skill-creator" = config.agents.skills.skill-creator;
        "alerting-irm" = config.agents.skills.grafana-core;
        "alloy" = config.agents.skills.grafana-core;
        "beyla" = config.agents.skills.grafana-core;
        "dashboarding" = config.agents.skills.grafana-core;
        "grafana-oss" = config.agents.skills.grafana-core;
        "opentelemetry" = config.agents.skills.grafana-core;
        "promql" = config.agents.skills.grafana-core;
        "skill-authoring" = config.agents.skills.grafana-core;
        "loki" = config.agents.skills.grafana-lgtm;
        "mimir" = config.agents.skills.grafana-lgtm;
        "prometheus" = config.agents.skills.grafana-lgtm;
        "pyroscope" = config.agents.skills.grafana-lgtm;
        "tempo" = config.agents.skills.grafana-lgtm;
        "datasources-provisioning" = config.agents.skills.grafana-datasources;
        "stop-slop" = config.agents.skills.stop-slop;
        "handoff" = config.agents.skills.handoff;
        "grill-me" = config.agents.skills.grill-me;
        "caveman" = config.agents.skills.caveman;
        "cavecrew" = config.agents.skills.caveman;
        "caveman-commit" = config.agents.skills.caveman;
        "caveman-compress" = config.agents.skills.caveman;
        "caveman-discover" = config.agents.skills.caveman;
        "caveman-evidence-review" = config.agents.skills.caveman;
        "caveman-explore" = config.agents.skills.caveman;
        "caveman-help" = config.agents.skills.caveman;
        "caveman-learn" = config.agents.skills.caveman;
        "caveman-manage" = config.agents.skills.caveman;
        "caveman-optimize" = config.agents.skills.caveman;
        "caveman-review" = config.agents.skills.caveman;
        "caveman-setup" = config.agents.skills.caveman;
        "caveman-stats" = config.agents.skills.caveman;
        "investigate-first" = config.agents.skills.caveman;
        "lean-build" = config.agents.skills.caveman;
        "migration" = config.agents.skills.caveman;
        "safe-refactor" = config.agents.skills.caveman;
        "surgical-patch" = config.agents.skills.caveman;
        "verify-and-stop" = config.agents.skills.caveman;
        "skill-miner" = config.agents.skills.skill-optimizer;
        "skill-personalizer" = config.agents.skills.skill-optimizer;
        "skill-generalizer" = config.agents.skills.skill-optimizer;
      };
    in
    {
      options.opencode.enable = lib.mkEnableOption "Enable opencode AI coding agent";

      config = lib.mkIf config.opencode.enable {
        programs.opencode.enable = true;

        # Global context written to ~/.config/opencode/AGENTS.md, applied
        # across every opencode session. Content lives once in
        # config.agents.context (agents.nix), shared with Claude Code.
        programs.opencode.context = config.agents.context;

        programs.opencode.skills = skills;

        programs.opencode.themes = {
          vitesse-dark = ./opencode-themes/vitesse-dark.json;
        };

        programs.opencode.tui.theme = "vitesse-dark";

        programs.opencode.settings = {
          mcp = mcp;
          permission =
            (lib.genAttrs allowedMcpTools (_: "allow"))
            // (lib.genAttrs askMcpTools (_: "ask"))
            // {
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
