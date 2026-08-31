{ lib, ... }:
{
  options.dotagents.agents.orchestrate = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for orchestrate (dotagents/agents/orchestrate/agent.md).";
  };

  # The orchestrate opencode agent definition is the repo-source file
  # (dotagents/agents/orchestrate/agent.md). Unlike the subagents it is a
  # primary agent — the opencode default — so it has no tools of its own and
  # delegates every task through `task`. A real source path (not a string
  # interpolation of the whole-tree package outPath) keeps pure evaluation
  # working: home-manager's `agents` option (lib.isPath) copies it via
  # `source`, and the claude adapter can interpolate it into its runCommand
  # build scripts without an eval-time store import.
  config.dotagents.agents.orchestrate = lib.mkDefault ../../../dotagents/agents/orchestrate/agent.md;
}
