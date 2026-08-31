{ lib, config, ... }:
let
  # The nix opencode subagent definition lives in the whole-tree package at
  # $out/agents/nix/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix.
  local = config.dotagents.localPackages;
in
{
  options.dotagents.subagents.nix = lib.mkOption {
    type = lib.types.path;
    description = "opencode subagent definition for nix (built from ../dotagents/agents/nix/agent.md).";
  };

  config.dotagents.subagents.nix = lib.mkDefault "${local.whole-tree}/agents/nix/agent.md";
}
