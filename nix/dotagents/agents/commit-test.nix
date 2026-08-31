{ lib, ... }:
{
  options.dotagents.agents = {
    commit = lib.mkOption {
      type = lib.types.path;
      description = "opencode agent definition for commit (dotagents/agents/commit/agent.md).";
    };
    test = lib.mkOption {
      type = lib.types.path;
      description = "opencode agent definition for test (dotagents/agents/test/agent.md).";
    };
  };

  # The commit/test opencode subagent definitions are the repo-source files
  # (dotagents/agents/<name>/agent.md). Real source paths (not string
  # interpolations of the whole-tree package outPath) keep pure evaluation
  # working: home-manager's `agents` option copies them via `source`
  # (lib.isPath), and the claude adapter can interpolate them into its
  # runCommand build scripts without an eval-time store import.
  config = {
    dotagents.agents.commit = lib.mkDefault ../../../dotagents/agents/commit/agent.md;
    dotagents.agents.test = lib.mkDefault ../../../dotagents/agents/test/agent.md;
  };
}
