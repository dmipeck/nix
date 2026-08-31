{ lib, ... }:
{
  options.dotagents.agents.github = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for github (dotagents/agents/github/agent.md).";
  };

  # The github opencode subagent definition is the repo-source file
  # (dotagents/agents/github/agent.md). It speaks the github MCP server's full
  # registered surface (read + write), so adapters gate its registration on
  # the per-user github instance being enabled
  # (dotagents.mcps.github.enable). A real source path (not a string
  # interpolation of the whole-tree package outPath) keeps pure evaluation
  # working: home-manager's `agents` option copies it via `source`
  # (lib.isPath), and the claude adapter can interpolate it into its runCommand
  # build scripts without an eval-time store import.
  config.dotagents.agents.github = lib.mkDefault ../../../dotagents/agents/github/agent.md;
}
