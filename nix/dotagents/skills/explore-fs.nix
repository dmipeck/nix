{ lib, config, ... }:
let
  # The explore-fs skill ships as a dedicated bare-dir package at $out root
  # (like git-workflow), and its opencode subagent definition lives in the
  # whole-tree package at $out/agents/explore-fs/agent.md — all built from
  # ../dotagents by nix/dotagents/local.nix.
  local = config.dotagents.localPackages;
in
{
  options.dotagents.skills."explore-fs" = lib.mkOption {
    type = lib.types.package;
    description = "opencode skill package for explore-fs (local skill, built from ../dotagents/skills/explore-fs).";
  };

  options.dotagents.subagents."explore-fs" = lib.mkOption {
    type = lib.types.path;
    description = "opencode subagent definition for explore-fs (built from ../dotagents/agents/explore-fs/agent.md).";
  };

  config = {
    dotagents.skills."explore-fs" = lib.mkDefault local.explore-fs;
    dotagents.subagents."explore-fs" = lib.mkDefault "${local.whole-tree}/agents/explore-fs/agent.md";
  };
}
