{ ... }:
let
  # The GitHub-hosted remote MCP server — https://api.githubcopilot.com/mcp/
  # serves the same github-mcp-server tool surface, hosted by GitHub. The
  # tool lists below scope the host-side agent allowlists: the read-only
  # explore-github subagent opts into its reads via its `tools` frontmatter,
  # the read-write github agent gets the whole server.
  readTools = [
    "actions_get"
    "actions_list"
    "get_commit"
    "get_discussion"
    "get_discussion_comments"
    "get_file_contents"
    "get_job_logs"
    "get_label"
    "get_latest_release"
    "get_me"
    "get_release_by_tag"
    "get_repository_tree"
    "get_tag"
    "get_team_members"
    "get_teams"
    "github-mcp-server"
    "issue_read"
    "list_branches"
    "list_commits"
    "list_discussion_categories"
    "list_discussions"
    "list_issue_fields"
    "list_issues"
    "list_issue_types"
    "list_pull_requests"
    "list_releases"
    "list_repository_collaborators"
    "list_tags"
    "pull_request_read"
    "search_code"
    "search_commits"
    "search_issues"
    "search_pull_requests"
    "search_repositories"
    "search_users"
  ];

  # The write tools the server registers: PRs, issues, discussions, Actions
  # triggers, branches and pushes. None of them are in the explore-github
  # subagent's `tools` allowlist, so it stays read-only.
  writeTools = [
    "actions_run_trigger"
    "add_comment_to_pending_review"
    "add_issue_comment"
    "add_reply_to_pull_request_comment"
    "create_branch"
    "create_or_update_file"
    "create_pull_request"
    "discussion_comment_write"
    "issue_write"
    "merge_pull_request"
    "pull_request_review_write"
    "push_files"
    "sub_issue_write"
    "update_pull_request"
    "update_pull_request_branch"
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
      url = "https://api.githubcopilot.com/mcp/";
      readOnlyTools = readTools;
      writableTools = writeTools;
    };
  };
}
