{ lib, ... }:
let
  # Tool names from upstream gitea-mcp README (consolidated action-based
  # tools). Enum stays Nix-side; Server Definition is authored in mcp.json.
  readTools = [
    "get_gitea_mcp_server_version"
    "get_me"
    "get_user_orgs"
    "search_users"
    "search_org_teams"
    "search_repos"
    "search_issues"
    "notification_read"
    "label_read"
    "milestone_read"
    "wiki_read"
    "timetracking_read"
    "package_read"
    "list_issues"
    "attachment_read"
    "issue_read"
    "list_pull_requests"
    "pull_request_read"
    "actions_config_read"
    "actions_run_read"
    "list_my_repos"
    "list_org_repos"
    "get_repository_tree"
    "get_file_contents"
    "get_dir_contents"
    "list_branches"
    "get_tag"
    "list_tags"
    "list_commits"
    "get_commit"
    "get_release"
    "get_latest_release"
    "list_releases"
  ];

  writeTools = [
    "notification_write"
    "label_write"
    "milestone_write"
    "wiki_write"
    "timetracking_write"
    "package_write"
    "issue_write"
    "pull_request_write"
    "pull_request_review_write"
    "actions_config_write"
    "actions_run_write"
    "create_repo"
    "fork_repo"
    "create_or_update_file"
    "delete_file"
    "create_branch"
    "delete_branch"
    "rename_branch"
    "create_tag"
    "delete_tag"
    "create_release"
    "delete_release"
  ];
in
{
  config.dotagents.mcpServers.gitea = {
    _module.args.mcpToolEnum = lib.types.enum (readTools ++ writeTools);
    tools.read = readTools;
    tools.write = writeTools;
  };
}
