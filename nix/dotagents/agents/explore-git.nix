{ lib, ... }:
{
  options.dotagents.agents."explore-git" = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for explore-git (dotagents/agents/explore-git/agent.md).";
  };

  # The explore-git opencode subagent definition is the repo-source file
  # (dotagents/agents/explore-git/agent.md). It is a read-only git observer:
  # it runs only `git` commands via bash and never mutates. A real source path
  # (not a string interpolation of the whole-tree package outPath) keeps pure
  # evaluation working: home-manager's `agents` option copies it via `source`
  # (lib.isPath), and the claude adapter can interpolate it into its runCommand
  # build scripts without an eval-time store import.
  config.dotagents.agents."explore-git" =
    lib.mkDefault ../../../dotagents/agents/explore-git/agent.md;
}
