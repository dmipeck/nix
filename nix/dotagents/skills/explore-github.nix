{ lib, config, ... }:
let
  # The explore-github opencode subagent definition lives in the whole-tree
  # package at $out/agents/explore-github/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix. It speaks the github MCP server's read-only git
  # tools, so adapters gate its registration on the per-user github instance
  # being enabled (dotagents.instance.github.enable).
  local = config.dotagents.localPackages;
in
{
  options.dotagents.subagents."explore-github" = lib.mkOption {
    type = lib.types.path;
    description = "opencode subagent definition for explore-github (built from ../dotagents/agents/explore-github/agent.md).";
  };

  config.dotagents.subagents."explore-github" =
    lib.mkDefault "${local.whole-tree}/agents/explore-github/agent.md";
}
