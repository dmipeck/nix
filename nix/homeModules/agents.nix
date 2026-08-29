{ inputs, ... }@flakeArgs:

{
  # flake-parts level: import the dmipeck/agents flakeModule so this flake's
  # eval exposes its `agents` options (skills, mcps, commands). The claude and
  # opencode adapters read `config.agents.skills` from here; the home-manager
  # module below owns the nix-repo-specific wiring (MCP server configs,
  # per-user instance options, global context).
  imports = [
    inputs.agents.flakeModules.agents
  ];

  # Home-manager config layer for the tool-agnostic "AI coding assistant"
  # core. Declares the MCP servers both Claude Code and opencode consume, plus
  # the per-user instance options (grafana / gitlab).
  #
  # Skill/plugin packages no longer live here — they're packaged in the
  # dmipeck/agents repo (`config.agents.skills`, see claude.nix / opencode.nix
  # which capture them from this flake's eval). Add a new MCP server here; add
  # a new skill over in dmipeck/agents.
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

      config.agents = {
        # Global agent instructions, shared by both tools (written to
        # ~/.config/opencode/AGENTS.md and ~/.claude/CLAUDE.md). The
        # git-workflow and caveman skills it references are installed from the
        # dmipeck/agents skill set, so the loads resolve.
        context = ''
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

        mcpServers = {
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
    };
}
