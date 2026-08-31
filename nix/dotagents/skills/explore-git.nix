{ lib, config, ... }:
let
  # The explore-git opencode subagent definition lives in the whole-tree
  # package at $out/agents/explore-git/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix. It is a read-only git observer: it runs only
  # `git` commands via bash and never mutates.
  local = config.dotagents.localPackages;
in
{
  options.dotagents.subagents."explore-git" = lib.mkOption {
    type = lib.types.path;
    description = "opencode subagent definition for explore-git (built from ../dotagents/agents/explore-git/agent.md).";
  };

  config.dotagents.subagents."explore-git" =
    lib.mkDefault "${local.whole-tree}/agents/explore-git/agent.md";
}
