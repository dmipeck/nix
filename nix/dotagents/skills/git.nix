{ lib, config, ... }:
let
  # The git opencode subagent definition lives in the whole-tree package at
  # $out/agents/git/agent.md, built from ../dotagents by nix/dotagents/local.nix.
  # It has read/write access to git: it runs any `git` command via bash to do
  # the git task asked of it.
  local = config.dotagents.localPackages;
in
{
  options.dotagents.subagents.git = lib.mkOption {
    type = lib.types.path;
    description = "opencode subagent definition for git (built from ../dotagents/agents/git/agent.md).";
  };

  config.dotagents.subagents.git = lib.mkDefault "${local.whole-tree}/agents/git/agent.md";
}
