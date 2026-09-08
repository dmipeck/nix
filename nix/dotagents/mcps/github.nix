{ lib, ... }:
let
  # The GitHub-hosted remote MCP server — https://api.githubcopilot.com/mcp/
  # serves the same github-mcp-server tool surface, hosted by GitHub. The
  # default endpoint (/) exposes only the default toolset (context, repos,
  # issues, pull_requests, users); /x/all exposes the full tool list across
  # every toolset. The tool lists below scope the host-side agent
  # allowlists: the read-only explore-github subagent opts into its reads
  # via its `tools` frontmatter, the read-write github agent gets the whole
  # server.
  readTools = [
    "actions_get"
    "actions_list"
    "get_job_logs"
    "get_code_quality_finding"
    "get_code_scanning_alert"
    "list_code_scanning_alerts"
    "get_me"
    "get_team_members"
    "get_teams"
    "get_dependabot_alert"
    "list_dependabot_alerts"
    "get_discussion"
    "get_discussion_comments"
    "list_discussion_categories"
    "list_discussions"
    "get_gist"
    "list_gists"
    "get_repository_tree"
    "custom_properties_read"
    "repository_ruleset_read"
    "get_label"
    "issue_read"
    "list_issue_fields"
    "list_issue_types"
    "list_issues"
    "search_issues"
    "list_label"
    "get_notification_details"
    "list_notifications"
    "search_orgs"
    "projects_get"
    "projects_list"
    "list_pull_requests"
    "pull_request_read"
    "search_pull_requests"
    "get_commit"
    "get_file_contents"
    "get_latest_release"
    "get_release_by_tag"
    "get_tag"
    "list_branches"
    "list_commits"
    "list_releases"
    "list_repository_collaborators"
    "list_tags"
    "search_code"
    "search_commits"
    "search_repositories"
    "get_secret_scanning_alert"
    "list_secret_scanning_alerts"
    "get_global_security_advisory"
    "list_global_security_advisories"
    "list_org_repository_security_advisories"
    "list_repository_security_advisories"
    "list_starred_repositories"
    "search_users"
    "get_copilot_space"
    "list_copilot_spaces"
    "github_support_docs_search"
  ];

  # The write tools the server registers: PRs, issues, discussions, Actions
  # triggers, branches and pushes. None of them are in the explore-github
  # subagent's `tools` allowlist, so it stays read-only.
  writeTools = [
    "actions_run_trigger"
    "assign_copilot_to_issue"
    "request_copilot_review"
    "assign_copilot_to_issue_with_intent"
    "discussion_comment_write"
    "create_gist"
    "update_gist"
    "create_repository_ruleset"
    "custom_properties_write"
    "add_issue_comment"
    "issue_write"
    "sub_issue_write"
    "label_write"
    "dismiss_notification"
    "manage_notification_subscription"
    "manage_repository_notification_subscription"
    "mark_all_notifications_read"
    "projects_write"
    "add_comment_to_pending_review"
    "add_reply_to_pull_request_comment"
    "create_pull_request"
    "merge_pull_request"
    "pull_request_review_write"
    "update_pull_request"
    "update_pull_request_branch"
    "create_branch"
    "create_or_update_file"
    "create_repository"
    "delete_file"
    "delete_repository"
    "fork_repository"
    "push_files"
    "star_repository"
    "unstar_repository"
    "create_pull_request_with_copilot"
  ];
in
{
  config.dotagents.mcpServers = {
    # Read-write GitHub server, hosted by GitHub. The hosted server does not
    # support dynamic client registration, so a pre-registered OAuth App
    # (clientId/clientSecret/scope) can be attached per-profile via
    # `dotagents.mcps.github.oauth`; without one it falls back to interactive
    # OAuth on first use — opencode's default for remote MCP servers — so no
    # local binary is needed.
    github = {
      type = "remote";
      url = "https://api.githubcopilot.com/mcp/x/all";
      _module.args.mcpToolEnum = lib.types.enum (readTools ++ writeTools);
      tools.read = readTools;
      tools.write = writeTools;
    };
  };
}
