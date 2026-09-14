{ lib, ... }:
let
  readTools = [
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
in
{
  # Tool enum only — command/args/env from mcp.json + Instance overlay.
  config.dotagents.mcpServers.grafana = {
    _module.args.mcpToolEnum = lib.types.enum readTools;
    tools.read = readTools;
  };
}
