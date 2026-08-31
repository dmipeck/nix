{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem, mirroring the
  # skills modules. The package is a nixpkgs derivation; evaluation stays lazy
  # until a consumer forces it.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # github-mcp-server only registers the tools it's told about. The surface is
  # a full developer workflow: context (who am I), actions (view/trigger
  # workflow runs), discussions, git/repos for code reads and pushes, issues,
  # pull_requests, and users. Verified against github-mcp-server 1.8.0:
  # `--toolsets ${toolsets} --exclude-tools <this list>` registers 50 tools.
  toolsets = "actions,context,discussions,git,issues,pull_requests,repos,users";

  # Write tools inside the enabled toolsets that are account/repo-level
  # destructive or surprising — creating or forking a repository, and deleting
  # a file outside a normal git flow. Excluded server-side so the tools do not
  # exist to be called; the host-level permission lists (opencode/claude) are
  # pure defence-in-depth.
  excludedTools = [
    "create_repository"
    "delete_file"
    "fork_repository"
  ];
in
{
  config.dotagents.mcpServers.github = {
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
    # a sops-decrypted file at startup (see dmipeck/nix homeModules/dotagents.nix).
    env = {
      GITHUB_PERSONAL_ACCESS_TOKEN = "";
    };
    # Read tools as registered by github-mcp-server 1.8.0 for the enabled
    # toolsets above; allow-listed on the host side.
    readOnlyTools = [
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
    # The write tools registered by the server (minus the excluded
    # repo/account-level ops above): PRs, issues, discussions, Actions
    # triggers, branches and pushes. Explicit `ask`/prompt candidates on the
    # host side.
    writableTools = [
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
  };
}
