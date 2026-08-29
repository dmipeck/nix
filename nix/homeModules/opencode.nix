{

  flake.homeModules.opencode =
    {
      lib,
      config,
      ...
    }:
    let
      # Neutral MCP servers + skill packages + per-user instance options live
      # in modules/homeModules/ai-tools.nix; this module is a thin adapter that
      # maps them onto opencode's config dialect and renders opencode's
      # permission rules from the shared per-server tool lists.
      mcpServers = config.aiTools.mcpServers;

      # opencode namespaces every MCP tool as `<server>_<tool>`. It allows
      # everything by default, so the allow-lists are explicit defence-in-depth
      # on top of the read-only MCP servers (argocd + grafana); the gitlab write
      # tools (which claude prompts on) and the bash denies preserve claude's
      # "prompt on anything not explicitly allowed" behaviour in opencode's
      # permissive model.
      allowedMcpTools = lib.concatLists (
        lib.mapAttrsToList (
          name: srv: map (tool: "${name}_${tool}") srv.readOnlyTools
        ) mcpServers
      );
      askMcpTools = lib.concatLists (
        lib.mapAttrsToList (
          name: srv: map (tool: "${name}_${tool}") srv.writableTools
        ) mcpServers
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
      skills = lib.mapAttrs' (
        name: pkg:
        lib.nameValuePair name "${pkg}/skills/${name}"
      ) {
        "build-mcp-app" = config.aiTools.skills.mcp-server-dev;
        "build-mcpb" = config.aiTools.skills.mcp-server-dev;
        "build-mcp-server" = config.aiTools.skills.mcp-server-dev;
        "skill-creator" = config.aiTools.skills.skill-creator;
        "alerting-irm" = config.aiTools.skills.grafana-core;
        "alloy" = config.aiTools.skills.grafana-core;
        "beyla" = config.aiTools.skills.grafana-core;
        "dashboarding" = config.aiTools.skills.grafana-core;
        "grafana-oss" = config.aiTools.skills.grafana-core;
        "opentelemetry" = config.aiTools.skills.grafana-core;
        "promql" = config.aiTools.skills.grafana-core;
        "skill-authoring" = config.aiTools.skills.grafana-core;
        "loki" = config.aiTools.skills.grafana-lgtm;
        "mimir" = config.aiTools.skills.grafana-lgtm;
        "prometheus" = config.aiTools.skills.grafana-lgtm;
        "pyroscope" = config.aiTools.skills.grafana-lgtm;
        "tempo" = config.aiTools.skills.grafana-lgtm;
        "datasources-provisioning" = config.aiTools.skills.grafana-datasources;
        "git-workflow" = config.aiTools.skills.git-workflow;
        "stop-slop" = config.aiTools.skills.stop-slop;
        "handoff" = config.aiTools.skills.handoff;
        "grill-me" = config.aiTools.skills.grill-me;
        "caveman" = config.aiTools.skills.caveman;
        "cavecrew" = config.aiTools.skills.caveman;
        "caveman-commit" = config.aiTools.skills.caveman;
        "caveman-compress" = config.aiTools.skills.caveman;
        "caveman-discover" = config.aiTools.skills.caveman;
        "caveman-evidence-review" = config.aiTools.skills.caveman;
        "caveman-explore" = config.aiTools.skills.caveman;
        "caveman-help" = config.aiTools.skills.caveman;
        "caveman-learn" = config.aiTools.skills.caveman;
        "caveman-manage" = config.aiTools.skills.caveman;
        "caveman-optimize" = config.aiTools.skills.caveman;
        "caveman-review" = config.aiTools.skills.caveman;
        "caveman-setup" = config.aiTools.skills.caveman;
        "caveman-stats" = config.aiTools.skills.caveman;
        "investigate-first" = config.aiTools.skills.caveman;
        "lean-build" = config.aiTools.skills.caveman;
        "migration" = config.aiTools.skills.caveman;
        "safe-refactor" = config.aiTools.skills.caveman;
        "surgical-patch" = config.aiTools.skills.caveman;
        "verify-and-stop" = config.aiTools.skills.caveman;
        "skill-miner" = config.aiTools.skills.skill-optimizer;
        "skill-personalizer" = config.aiTools.skills.skill-optimizer;
        "skill-generalizer" = config.aiTools.skills.skill-optimizer;
      };
    in
    {
      options.opencode.enable = lib.mkEnableOption "Enable opencode AI coding agent";

      config = lib.mkIf config.opencode.enable {
        programs.opencode.enable = true;

        # Global context written to ~/.config/opencode/AGENTS.md, applied
        # across every opencode session. Content lives once in
        # config.aiTools.context (ai-tools.nix), shared with Claude Code.
        programs.opencode.context = config.aiTools.context;

        programs.opencode.skills = skills;

        programs.opencode.themes = {
          vitesse-dark = ./opencode-themes/vitesse-dark.json;
        };

        programs.opencode.tui.theme = "vitesse-dark";

        programs.opencode.settings = {
          mcp = mcp;
          permission = (lib.genAttrs allowedMcpTools (_: "allow"))
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
