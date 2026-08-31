{ lib, ... }:
{
  config.dotagents.mcpServers.gitlab = {
    type = "remote";
    # url is a per-user placeholder; filled in by the consumer's home-manager
    # config (see dmipeck/nix homeModules/dotagents.nix).
    url = null;
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
}
