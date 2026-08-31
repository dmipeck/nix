{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem, mirroring the
  # skills modules. The package is a nixpkgs derivation; evaluation stays lazy
  # until a consumer forces it.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);
in
{
  config.dotagents.mcpServers.grafana = {
    type = "local";
    command = "${pkgs.mcp-grafana}/bin/mcp-grafana";
    args = [
      "-t"
      "stdio"
      # Block dashboard/alerting/etc create-update tools, leaving only
      # inspection.
      "-disable-write"
    ];
    # Per-user secrets are placeholders here; filled in by the consumer's
    # home-manager config (see dmipeck/nix homeModules/dotagents.nix).
    env = {
      GRAFANA_URL = "";
      GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = "";
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
