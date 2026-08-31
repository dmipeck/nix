{ lib, ... }:
{
  options.dotagents.agents.git = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for git (dotagents/agents/git/agent.md).";
  };

  # The git opencode subagent definition is the repo-source file
  # (dotagents/agents/git/agent.md). It has read/write access to git: it runs
  # any `git` command via bash to do the git task asked of it. A real source
  # path (not a string interpolation of the whole-tree package outPath) keeps
  # pure evaluation working: home-manager's `agents` option copies it via
  # `source` (lib.isPath), and the claude adapter can interpolate it into its
  # runCommand build scripts without an eval-time store import.
  config.dotagents.agents.git = lib.mkDefault ../../../dotagents/agents/git/agent.md;
}
