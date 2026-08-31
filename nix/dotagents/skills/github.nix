{ lib, config, ... }:
let
  # The github opencode subagent definition lives in the whole-tree package at
  # $out/agents/github/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix. It speaks the github MCP server's full registered
  # surface (read + write), so adapters gate its registration on the per-user
  # github instance being enabled (dotagents.instance.github.enable).
  local = config.dotagents.localPackages;
in
{
  options.dotagents.subagents.github = lib.mkOption {
    type = lib.types.path;
    description = "opencode subagent definition for github (built from ../dotagents/agents/github/agent.md).";
  };

  config.dotagents.subagents.github = lib.mkDefault "${local.whole-tree}/agents/github/agent.md";
}
