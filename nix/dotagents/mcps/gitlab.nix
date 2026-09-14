{ lib, ... }:
let
  readTools = [
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
  writeTools = [
    "create_issue"
    "create_merge_request"
    "create_merge_request_note"
    "add_branch"
    "manage_pipeline"
    "create_workitem_note"
    "link_work_items"
    "attach_scan_profile"
  ];
in
{
  # Tool enum only — url comes from Instance overlay on authored mcp.json.
  config.dotagents.mcpServers.gitlab = {
    _module.args.mcpToolEnum = lib.types.enum (readTools ++ writeTools);
    tools.read = readTools;
    tools.write = writeTools;
  };
}
