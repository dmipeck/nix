{ lib, config, ... }:
let
  # The explore-fs opencode subagent definition lives in the whole-tree
  # package at $out/agents/explore-fs/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix.
  local = config.dotagents.localPackages;
in
{
  options.dotagents.subagents."explore-fs" = lib.mkOption {
    type = lib.types.path;
    description = "opencode subagent definition for explore-fs (built from ../dotagents/agents/explore-fs/agent.md).";
  };

  config.dotagents.subagents."explore-fs" =
    lib.mkDefault "${local.whole-tree}/agents/explore-fs/agent.md";
}
