{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem, mirroring the
  # skills modules. The package is a nixpkgs derivation; evaluation stays lazy
  # until a consumer forces it.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);
in
{
  config.agents.mcpServers.github = {
    type = "local";
    command = "${pkgs.github-mcp-server}/bin/github-mcp-server";
    args = [
      "stdio"
    ];
    # GITHUB_PERSONAL_ACCESS_TOKEN is a per-user secret placeholder; filled in
    # by the consumer's home-manager config (see dmipeck/nix
    # homeModules/agents.nix).
    env = {
      GITHUB_PERSONAL_ACCESS_TOKEN = "";
    };
    # github-mcp-server exposes both read and write tools with no read-only
    # flag of its own, so only the individually-verified read-only tools are
    # allow-listed; the write tools are explicit `ask`/prompt candidates.
    readOnlyTools = [
      "actions_get"
      "actions_list"
      "get_code_quality_finding"
      "get_code_scanning_alert"
      "get_commit"
      "get_copilot_space"
      "get_dependabot_alert"
      "get_discussion"
      "get_discussion_comments"
      "get_file_contents"
      "get_gist"
      "get_global_security_advisory"
      "get_job_logs"
      "get_label"
      "get_latest_release"
      "get_me"
      "get_notification_details"
      "get_release_by_tag"
      "get_repository_tree"
      "get_secret_scanning_alert"
      "get_tag"
      "get_team_members"
      "get_teams"
      "github_support_docs_search"
      "issue_read"
      "list_branches"
      "list_code_scanning_alerts"
      "list_commits"
      "list_copilot_spaces"
      "list_dependabot_alerts"
      "list_discussion_categories"
      "list_discussions"
      "list_gists"
      "list_global_security_advisories"
      "list_issue_fields"
      "list_issue_types"
      "list_issues"
      "list_label"
      "list_notifications"
      "list_org_repository_security_advisories"
      "list_pull_requests"
      "list_releases"
      "list_repository_collaborators"
      "list_repository_security_advisories"
      "list_secret_scanning_alerts"
      "list_starred_repositories"
      "list_tags"
      "projects_get"
      "projects_list"
      "pull_request_read"
      "search_code"
      "search_commits"
      "search_issues"
      "search_orgs"
      "search_pull_requests"
      "search_repositories"
      "search_users"
    ];
    writableTools = [
      "actions_run_trigger"
      "add_comment_to_pending_review"
      "add_issue_comment"
      "add_reply_to_pull_request_comment"
      "assign_copilot_to_issue"
      "assign_copilot_to_issue_with_intent"
      "create_branch"
      "create_gist"
      "create_or_update_file"
      "create_pull_request"
      "create_pull_request_with_copilot"
      "create_repository"
      "delete_file"
      "delete_repository"
      "dismiss_notification"
      "discussion_comment_write"
      "fork_repository"
      "issue_write"
      "label_write"
      "manage_notification_subscription"
      "manage_repository_notification_subscription"
      "mark_all_notifications_read"
      "merge_pull_request"
      "projects_write"
      "pull_request_review_write"
      "push_files"
      "request_copilot_review"
      "star_repository"
      "sub_issue_write"
      "unstar_repository"
      "update_gist"
      "update_pull_request"
      "update_pull_request_branch"
    ];
  };
}
