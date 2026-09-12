{ lib, ... }:
let
  # Local GitHub MCP (ghcr.io/github/github-mcp-server) — Docker stdio with
  # OAuth via the baked-in GitHub app and a fixed loopback callback port.
  # `--toolsets all` matches the former remote `/x/all` surface for local
  # toolsets; host-side allowlists below still scope explore-github (read)
  # vs github (read+write). Remote-only toolsets (copilot_spaces,
  # github_support_docs_search) are omitted so the enum stays coherent with
  # what the local full toolset actually registers.
  image = "ghcr.io/github/github-mcp-server:v1.12.1";

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
    # Local Docker stdio GitHub MCP. OAuth uses the image's baked-in app and
    # GITHUB_OAUTH_CALLBACK_PORT on loopback (default 8085 here; Instance
    # `dotagents.mcps.github.callbackPort` overlays the publish mapping + env).
    # No host-side clientId / clientSecret on the Server Definition.
    # Per-profile enable: `dotagents.mcps.github.enable`.
    github = {
      type = "local";
      command = "docker";
      args = [
        "run"
        "-i"
        "--rm"
        "-p"
        "127.0.0.1:8085:8085"
        "-e"
        "GITHUB_OAUTH_CALLBACK_PORT"
        image
        "stdio"
        "--toolsets"
        "all"
      ];
      env = {
        GITHUB_OAUTH_CALLBACK_PORT = "8085";
      };
      _module.args.mcpToolEnum = lib.types.enum (readTools ++ writeTools);
      tools.read = readTools;
      tools.write = writeTools;
    };
  };
}
