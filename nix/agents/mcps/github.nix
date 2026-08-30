{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem, mirroring the
  # skills modules. The package is a nixpkgs derivation; evaluation stays lazy
  # until a consumer forces it.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # github-mcp-server only registers the tools it's told about. Pin the
  # surface to the PR workflow: context (who am I), git/repos for code reads
  # and pushes, issues and pull_requests for reading issues, PRs, comments and
  # reviews, and users. Everything outside these toolsets (actions, gists,
  # labels, projects, orgs, copilot, notifications, ...) is never registered.
  toolsets = "context,git,issues,pull_requests,repos,users";

  # Write tools inside the enabled toolsets that go beyond "open a PR, push
  # changes" — merging, repo create/delete/fork, file delete, and
  # issue/comment/review/PR-state writes. Excluded server-side so the tools do
  # not exist to be called; the host-level permission lists (opencode/claude)
  # are pure defence-in-depth. Verified against github-mcp-server 1.8.0:
  # `--toolsets ${toolsets} --exclude-tools <this list>` registers 32 tools.
  excludedTools = [
    "add_comment_to_pending_review"
    "add_issue_comment"
    "add_issue_comment_reaction"
    "add_issue_reaction"
    "add_pull_request_review_comment"
    "add_pull_request_review_comment_reaction"
    "add_reply_to_pull_request_comment"
    "add_sub_issue"
    "create_issue"
    "create_pull_request_review"
    "create_repository"
    "delete_file"
    "delete_pending_pull_request_review"
    "delete_repository"
    "fork_repository"
    "issue_dependency_write"
    "issue_write"
    "merge_pull_request"
    "pull_request_review_write"
    "remove_sub_issue"
    "reprioritize_sub_issue"
    "request_pull_request_reviewers"
    "resolve_review_thread"
    "set_issue_fields"
    "sub_issue_write"
    "submit_pending_pull_request_review"
    "unresolve_review_thread"
    "update_issue_assignees"
    "update_issue_body"
    "update_issue_labels"
    "update_issue_milestone"
    "update_issue_state"
    "update_issue_title"
    "update_issue_type"
    "update_pull_request_body"
    "update_pull_request_branch"
    "update_pull_request_draft_state"
    "update_pull_request_state"
    "update_pull_request_title"
  ];
in
{
  config.agents.mcpServers.github = {
    type = "local";
    command = "${pkgs.github-mcp-server}/bin/github-mcp-server";
    args = [
      "stdio"
      "--toolsets"
      toolsets
      "--exclude-tools"
      (lib.concatStringsSep "," excludedTools)
    ];
    # GITHUB_PERSONAL_ACCESS_TOKEN is a per-user secret placeholder; the
    # consumer's home-manager config wraps the server so the PAT is read from
    # a sops-decrypted file at startup (see dmipeck/nix homeModules/agents.nix).
    env = {
      GITHUB_PERSONAL_ACCESS_TOKEN = "";
    };
    # Read tools as registered by github-mcp-server 1.8.0 for the enabled
    # toolsets above; allow-listed on the host side.
    readOnlyTools = [
      "get_commit"
      "get_file_contents"
      "get_label"
      "get_latest_release"
      "get_me"
      "get_release_by_tag"
      "get_repository_tree"
      "get_tag"
      "get_team_members"
      "get_teams"
      "issue_read"
      "list_branches"
      "list_commits"
      "list_issue_fields"
      "list_issue_types"
      "list_issues"
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
    # The only write tools registered by the server: open a PR, push changes.
    # Explicit `ask`/prompt candidates on the host side.
    writableTools = [
      "create_branch"
      "create_or_update_file"
      "push_files"
      "create_pull_request"
      "update_pull_request"
    ];
  };
}
