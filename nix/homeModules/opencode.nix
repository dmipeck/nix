{ config, ... }@flakeArgs:
let
  # Skill/plugin packages are owned by the dmipeck/agents repo. `config` here
  # is flake-parts state (agents.nix imports inputs.agents.flakeModules.agents);
  # captured once so the home-manager module below can reference the packages.
  agentSkills = flakeArgs.config.agents.skills;
in
{
  flake.homeModules.opencode =
    {
      lib,
      config,
      ...
    }:
    let
      # Neutral MCP server configs + per-user instance options live in
      # homeModules/agents.nix; skill packages come from the dmipeck/agents
      # flakeModule (`agentSkills`, captured above). This module is a thin
      # adapter that maps them onto opencode's config dialect and renders
      # opencode's permission rules from the shared per-server tool lists.
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
      # wants each skill referenced by its directory path. git-workflow is
      # exceptional: dmipeck/agents ships it as a bare directory (not a
      # $out/skills/<name> package), so it's referenced directly.
      skills =
        lib.mapAttrs' (name: pkg: lib.nameValuePair name "${pkg}/skills/${name}") {
          "build-mcp-app" = agentSkills.mcp-server-dev;
          "build-mcpb" = agentSkills.mcp-server-dev;
          "build-mcp-server" = agentSkills.mcp-server-dev;
          "skill-creator" = agentSkills.skill-creator;
          "alerting-irm" = agentSkills.grafana-core;
          "alloy" = agentSkills.grafana-core;
          "beyla" = agentSkills.grafana-core;
          "dashboarding" = agentSkills.grafana-core;
          "grafana-oss" = agentSkills.grafana-core;
          "opentelemetry" = agentSkills.grafana-core;
          "promql" = agentSkills.grafana-core;
          "skill-authoring" = agentSkills.grafana-core;
          "loki" = agentSkills.grafana-lgtm;
          "mimir" = agentSkills.grafana-lgtm;
          "prometheus" = agentSkills.grafana-lgtm;
          "pyroscope" = agentSkills.grafana-lgtm;
          "tempo" = agentSkills.grafana-lgtm;
          "datasources-provisioning" = agentSkills.grafana-datasources;
          "stop-slop" = agentSkills.stop-slop;
          "handoff" = agentSkills.handoff;
          "grill-me" = agentSkills.grill-me;
          "caveman" = agentSkills.caveman;
          "cavecrew" = agentSkills.caveman;
          "caveman-commit" = agentSkills.caveman;
          "caveman-compress" = agentSkills.caveman;
          "caveman-discover" = agentSkills.caveman;
          "caveman-evidence-review" = agentSkills.caveman;
          "caveman-explore" = agentSkills.caveman;
          "caveman-help" = agentSkills.caveman;
          "caveman-learn" = agentSkills.caveman;
          "caveman-manage" = agentSkills.caveman;
          "caveman-optimize" = agentSkills.caveman;
          "caveman-review" = agentSkills.caveman;
          "caveman-setup" = agentSkills.caveman;
          "caveman-stats" = agentSkills.caveman;
          "investigate-first" = agentSkills.caveman;
          "lean-build" = agentSkills.caveman;
          "migration" = agentSkills.caveman;
          "safe-refactor" = agentSkills.caveman;
          "surgical-patch" = agentSkills.caveman;
          "verify-and-stop" = agentSkills.caveman;
          "skill-miner" = agentSkills.skill-optimizer;
          "skill-personalizer" = agentSkills.skill-optimizer;
          "skill-generalizer" = agentSkills.skill-optimizer;
        }
        // {
          "git-workflow" = "${agentSkills.git-workflow}";
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
