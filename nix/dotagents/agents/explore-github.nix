{ lib, ... }:
{
  options.dotagents.agents."explore-github" = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for explore-github (dotagents/agents/explore-github/agent.md).";
  };

  # The explore-github opencode subagent definition is the repo-source file
  # (dotagents/agents/explore-github/agent.md). It speaks the github MCP
  # server's read-only git tools, so adapters gate its registration on the
  # per-user github instance being enabled
  # (dotagents.mcps.github.enable). A real source path (not a string
  # interpolation of the whole-tree package outPath) keeps pure evaluation
  # working: home-manager's `agents` option copies it via `source`
  # (lib.isPath), and the claude adapter can interpolate it into its runCommand
  # build scripts without an eval-time store import.
  config.dotagents.agents."explore-github" =
    lib.mkDefault ../../../dotagents/agents/explore-github/agent.md;
}
