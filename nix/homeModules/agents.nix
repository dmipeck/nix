{ inputs, config, ... }@flakeArgs:

{
  # Shared, tool-agnostic "AI coding assistant" core. Declares the MCP
  # servers and skill packages that both Claude Code and opencode consume,
  # plus the per-user instance options (grafana / gitlab) that were
  # previously duplicated across the claude and opencode home modules.
  #
  # Each tool (modules/homeModules/claude.nix, modules/homeModules/opencode.nix)
  # is a thin adapter that maps these neutral definitions onto its own config
  # dialect and renders its own permission allowlists from the shared tool
  # lists. A definition lives here exactly once; adding a new MCP server or
  # skill means editing this file alone.
  flake.homeModules.agents =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      instance = config.agents.instance;
    in
    {
      imports = [
        flakeArgs.config.flake.homeModules.agentsSkills
      ];

      options.agents = {
        # Shared global context (instructing the agent to load the git-workflow
        # and caveman skills) written to each AI tool's global rules file —
        # ~/.config/opencode/AGENTS.md for opencode, ~/.claude/CLAUDE.md for
        # Claude Code. Declared once here so both adapters stay in sync.
        context = lib.mkOption {
          type = lib.types.lines;
          description = ''
            Global agent instructions, applied across every session of each AI
            tool. Loads the git-workflow skill before working on a git repo and
            the caveman skill for terse communication.
          '';
        };

        instance = {
          grafana = {
            url = lib.mkOption {
              type = lib.types.str;
              description = "Grafana instance URL passed as GRAFANA_URL to the mcp-grafana MCP server.";
            };
            serviceAccountTokenSopsKey = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Name of the sops-nix secret holding the Grafana service account
                token. Its decrypted path is exposed to the mcp-grafana server
                via GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE. Leave as null to omit the
                token (empty string) — e.g. for anonymous/unauthenticated access.
              '';
            };
          };
          gitlab = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to add the gitlab MCP server to the AI tool's config.
                Off by default since not every profile has a GitLab instance to
                point it at; set to true and provide `agents.instance.gitlab.url`
                to enable it.
              '';
            };
            url = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Base URL of the GitLab instance the gitlab MCP server connects
                to. The server itself is remote HTTP (served by GitLab at
                "''${url}/api/v4/mcp") and authenticates interactively via OAuth
                2.0 on first use — no sops secret is needed here. Only read when
                `agents.instance.gitlab.enable` is true.
              '';
            };
          };
        };

        mcpServers = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              # Neutral MCP server model. Each consumer adapter re-shapes this
              # into its own dialect; `*Tools` lists drive permission allowlists.
              options = {
                type = lib.mkOption {
                  type = lib.types.enum [
                    "local"
                    "remote"
                  ];
                };
                command = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                args = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                };
                env = lib.mkOption {
                  type = lib.types.attrsOf lib.types.str;
                  default = { };
                };
                url = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                headers = lib.mkOption {
                  type = lib.types.attrsOf lib.types.str;
                  default = { };
                };
                readOnlyTools = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Read-only tools to allow without prompting.";
                };
                writableTools = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Mutating tools, to prompt/ask before running.";
                };
              };
            }
          );
        };
      };

      config.agents.mcpServers = {
        nixos = {
          type = "local";
          command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
          readOnlyTools = [ ];
        };
        playwright = {
          type = "local";
          command = "${pkgs.playwright-mcp}/bin/playwright-mcp";
          readOnlyTools = [ ];
        };
        kubernetes = {
          type = "local";
          command = "${pkgs.mcp-k8s-go}/bin/mcp-k8s-go";
          readOnlyTools = [
            "get-k8s-pod-logs"
            "get-k8s-resource"
            "list-k8s-contexts"
            "list-k8s-events"
            "list-k8s-namespaces"
            "list-k8s-nodes"
            "list-k8s-resources"
          ];
        };
        grafana = {
          type = "local";
          command = "${pkgs.mcp-grafana}/bin/mcp-grafana";
          args = [
            "-t"
            "stdio"
            # Block dashboard/alerting/etc create-update tools, leaving only
            # inspection.
            "-disable-write"
          ];
          env = {
            GRAFANA_URL = instance.grafana.url;
            # Points the server at the sops-decrypted secret *file* rather than
            # the token value itself, so the token never lands in the Nix store
            # or this repo. Left empty when unset, e.g. for anonymous access.
            GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE =
              if instance.grafana.serviceAccountTokenSopsKey != null then
                config.sops.secrets.${instance.grafana.serviceAccountTokenSopsKey}.path
              else
                "";
          };
          # mcp-grafana is started with -disable-write, so every tool it exposes
          # is read-only (readOnlyHint: true); the full set is allow-listed.
          readOnlyTools = [
            "alerting_manage_routing"
            "alerting_manage_rules"
            "analyze_loki_labels"
            "check_datasources_health"
            "generate_deeplink"
            "get_alert_group"
            "get_annotation_tags"
            "get_annotations"
            "get_assertions"
            "get_current_oncall_users"
            "get_dashboard_by_uid"
            "get_dashboard_panel_queries"
            "get_dashboard_property"
            "get_dashboard_summary"
            "get_datasource"
            "get_incident"
            "get_oncall_shift"
            "get_panel_image"
            "get_plugin"
            "get_sift_analysis"
            "get_sift_investigation"
            "get_snapshot"
            "grafana_api_request"
            "list_alert_groups"
            "list_datasources"
            "list_incidents"
            "list_loki_label_names"
            "list_loki_label_values"
            "list_oncall_schedules"
            "list_oncall_teams"
            "list_oncall_users"
            "list_prometheus_label_names"
            "list_prometheus_label_values"
            "list_prometheus_metric_metadata"
            "list_prometheus_metric_names"
            "list_provisioning_repositories"
            "list_pyroscope_label_names"
            "list_pyroscope_label_values"
            "list_pyroscope_profile_types"
            "list_sift_investigations"
            "list_snapshots"
            "query_loki_logs"
            "query_loki_patterns"
            "query_loki_stats"
            "query_prometheus"
            "query_prometheus_histogram"
            "query_pyroscope"
            "search_dashboards"
            "search_folders"
            "search_plugin_information"
            "suggest_loki_alloy_label_config"
            "validate_provisioning_file"
          ];
        };
      }
      // lib.optionalAttrs instance.gitlab.enable {
        gitlab = {
          type = "remote";
          url = "${instance.gitlab.url}/api/v4/mcp";
          # gitlab exposes both read and write tools with no read-only flag of
          # its own, so only the individually-verified read-only tools are
          # allow-listed; the write tools are explicit `ask`/prompt candidates.
          readOnlyTools = [
            "get_mcp_server_version"
            "get_issue"
            "get_merge_request"
            "list_merge_requests"
            "get_merge_request_commits"
            "get_merge_request_diffs"
            "get_merge_request_conflicts"
            "get_merge_request_pipelines"
            "get_merge_request_notes"
            "get_repository_file"
            "get_pipeline"
            "get_pipeline_jobs"
            "get_job_log"
            "list_pipelines"
            "get_workitem_notes"
            "get_work_item_types"
            "get_saved_view_work_items"
            "search"
            "search_labels"
            "list_wiki_pages"
            "semantic_code_search"
          ];
          writableTools = [
            "create_issue"
            "create_merge_request"
            "create_merge_request_note"
            "add_branch"
            "manage_pipeline"
            "create_workitem_note"
            "link_work_items"
            "attach_scan_profile"
          ];
        };
      };
    };

  # Skill/plugin packages, shared by both tools. Each upstream repo is fetched
  # once here (single source of truth for pins), and every package exposes
  # $out/skills/<name>/SKILL.md so Claude (plugins) and opencode (skills) can
  # both consume it.
  flake.homeModules.agentsSkills =
    { lib, pkgs, ... }:
    let
      claudePluginsOfficial = pkgs.fetchFromGitHub {
        owner = "anthropics";
        repo = "claude-plugins-official";
        rev = "a488bee3a01ce38125d372b560c9c7fa25d0deb6";
        hash = "sha256-8Ri0iSyAmayOEk/Jx7C9mGBQVeMTJE8hOVVMoU5B1Ps=";
      };
      # Build a derivation whose $out/ holds a full claude-plugins-official
      # plugin (with $out/skills/ subdirectory), satisfying both Claude's
      # plugin layout and opencode's skills/<name> lookup.
      mkPlugin =
        name:
        pkgs.runCommand "agents-plugin-${name}" { } ''
          cp -rL ${claudePluginsOfficial}/plugins/${name} $out
        '';
      # https://github.com/grafana/skills — a marketplace of skill groups, each
      # a subdirectory of skills/<group>/. Builds $out/skills/<name>/SKILL.md
      # per skill; Claude auto-discovers skills with no plugin manifest needed,
      # opencode reads $out/skills/<name>.
      grafanaSkillsSrc = pkgs.fetchFromGitHub {
        owner = "grafana";
        repo = "skills";
        rev = "51d33e71e191b409bbd25fc7be2684c610d18166";
        hash = "sha256-13pDO69zgLkDjJ49O/8a4ncmm6MTppAhDK8wioELpwY=";
      };
      mkGrafanaGroup =
        group:
        pkgs.runCommand "agents-grafana-${group}" { } ''
          mkdir -p $out/skills
          cp -rL ${grafanaSkillsSrc}/skills/${group}/. $out/skills/
        '';

      # https://github.com/hardikpandya/stop-slop — the repo root itself is the
      # skill (SKILL.md + references/), so subdir stays empty.
      stopSlopSrc = pkgs.fetchFromGitHub {
        owner = "hardikpandya";
        repo = "stop-slop";
        rev = "8da1f030185bdfe8471220585162991eaeb970e9";
        hash = "sha256-JMqlCRVEAfwG1TLMDpnamznkBfkmX6e2XyETTTH/TSE=";
      };
      # https://github.com/mattpocock/skills — a skill collection; handoff and
      # grill-me each live in their own subdirectory under skills/productivity/.
      mattpocockSkillsSrc = pkgs.fetchFromGitHub {
        owner = "mattpocock";
        repo = "skills";
        rev = "6654f6b60cd9d5be8b54c6fafe44346dabeb3b76";
        hash = "sha256-N5tpUIHO2VFeJntBTl6/VLDIVpqoshwFxNJlfXXUwsQ=";
      };
      # https://github.com/JuliusBrussee/caveman — the whole skills/ tree
      # (every subdirectory containing a SKILL.md), mirroring the grafana group
      # packaging above. Non-skill files (compile.mjs, generated/, ...) are
      # skipped by the SKILL.md test.
      cavemanSrc = pkgs.fetchFromGitHub {
        owner = "JuliusBrussee";
        repo = "caveman";
        rev = "17f9f2ec2377b0bfe16b52ee03a462e7f0a02bc8";
        hash = "sha256-lmzmlPj47lWNRZudMSsdIocS4srZYQeG2bQw800Os7U=";
      };
      # https://github.com/hqhq1025/skill-optimizer — a three-skill toolkit
      # (skill-miner, skill-personalizer, skill-generalizer).
      skillOptimizerSrc = pkgs.fetchFromGitHub {
        owner = "hqhq1025";
        repo = "skill-optimizer";
        rev = "b9ffd1513e84136b72e2b6f041dc1ebfd9e23a84";
        hash = "sha256-bmlc9nD0Tz62sy+Grvt6ZWhuNQjk6AjuMy0aLPw+ZE8=";
      };
      # Copy an arbitrary upstream sub-directory (or the repo root when subdir
      # is omitted) into $out/skills/<name>, producing the shared
      # $out/skills/<name>/SKILL.md layout both Claude plugins and opencode read.
      mkSkill =
        {
          name,
          src,
          subdir ? "",
        }:
        let
          skillSrc = if subdir == "" then src else "${src}/${subdir}";
        in
        pkgs.runCommand "agents-${name}" { } ''
          mkdir -p $out/skills/${name}
          cp -rL ${skillSrc}/. $out/skills/${name}/
        '';
      mkCavemanSkillPack = pkgs.runCommand "agents-caveman" { } ''
        mkdir -p $out/skills
        for d in ${cavemanSrc}/skills/*; do
          [ -f "$d/SKILL.md" ] || continue
          cp -rL "$d" "$out/skills/$(basename "$d")"
        done
      '';
      mkSkillOptimizerPack = pkgs.runCommand "agents-skill-optimizer" { } ''
        mkdir -p $out/skills
        cp -rL ${skillOptimizerSrc}/skills/skill-miner $out/skills/
        cp -rL ${skillOptimizerSrc}/skills/skill-personalizer $out/skills/
        cp -rL ${skillOptimizerSrc}/skills/skill-generalizer $out/skills/
      '';
    in
    {
      options.agents.skills = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        readOnly = true;
        description = "Skill/plugin packages keyed by plugin name ($out/skills/<name>/SKILL.md each).";
      };

      config.agents.context = ''
        # Global Agent Instructions

        ## Git repositories

        Before starting any work in a git repository, load the `git-workflow` skill:

        ```
        skill: git-workflow
        ```

        The skill contains the workflow and commit conventions that must be followed
        for every change taken from "about to start" to "merged". Load it before
        writing code, running commits, or opening pull requests.

        ## Communication style

        Load the `caveman` skill at the start of every session — always use
        ultra-compressed `caveman` communication mode unless the user explicitly
        requests otherwise:

        ```
        skill: caveman
        ```
      '';

      config.agents.skills = {
        mcp-server-dev = mkPlugin "mcp-server-dev";
        skill-creator = mkPlugin "skill-creator";
        grafana-core = mkGrafanaGroup "grafana-core";
        grafana-lgtm = mkGrafanaGroup "grafana-lgtm";
        grafana-datasources = mkGrafanaGroup "grafana-datasources";
        stop-slop = mkSkill {
          name = "stop-slop";
          src = stopSlopSrc;
        };
        handoff = mkSkill {
          name = "handoff";
          src = mattpocockSkillsSrc;
          subdir = "skills/productivity/handoff";
        };
        grill-me = mkSkill {
          name = "grill-me";
          src = mattpocockSkillsSrc;
          subdir = "skills/productivity/grill-me";
        };
        caveman = mkCavemanSkillPack;
        skill-optimizer = mkSkillOptimizerPack;
      };
    };
}
