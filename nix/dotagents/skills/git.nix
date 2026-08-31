{ lib, config, ... }:
let
  # The git opencode subagent definition lives in the whole-tree package at
  # $out/agents/git/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix. It speaks the github MCP server's git tools, so
  # adapters gate its registration on the per-user github instance being
  # enabled (dotagents.instance.github.enable).
  local = config.dotagents.localPackages;
in
{
  options.dotagents.subagents.git = lib.mkOption {
    type = lib.types.path;
    description = "opencode subagent definition for git (built from ../dotagents/agents/git/agent.md).";
  };

  config.dotagents.subagents.git = lib.mkDefault "${local.whole-tree}/agents/git/agent.md";
}
