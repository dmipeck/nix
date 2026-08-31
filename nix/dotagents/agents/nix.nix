{ lib, ... }:
{
  options.dotagents.agents.nix = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for nix (dotagents/agents/nix/agent.md).";
  };

  # The nix opencode subagent definition is the repo-source file
  # (dotagents/agents/nix/agent.md). A real source path (not a string
  # interpolation of the whole-tree package outPath) keeps pure evaluation
  # working: home-manager's `agents` option copies it via `source`
  # (lib.isPath), and the claude adapter can interpolate it into its
  # runCommand build scripts without an eval-time store import.
  config.dotagents.agents.nix = lib.mkDefault ../../../dotagents/agents/nix/agent.md;
}
