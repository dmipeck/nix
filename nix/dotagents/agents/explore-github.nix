{ lib, config, ... }:
let
  # The explore-github opencode subagent definition lives in the whole-tree
  # package at $out/agents/explore-github/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix. It speaks the github MCP server's read-only git
  # tools, so adapters gate its registration on the per-user github instance
  # being enabled (dotagents.instance.github.enable).
  local = config.dotagents.localPackages;

  # `outPath` is a string in Nix 2.34; `/. +` rebuilds it as a true path so
  # home-manager's `agents` option copies the file via `source` (lib.isPath).
  store = /. + builtins.unsafeDiscardStringContext local.whole-tree.outPath;
in
{
  options.dotagents.agents."explore-github" = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for explore-github (built from ../dotagents/agents/explore-github/agent.md).";
  };

  config.dotagents.agents."explore-github" = lib.mkDefault (
    store + "/agents/explore-github/agent.md"
  );
}
