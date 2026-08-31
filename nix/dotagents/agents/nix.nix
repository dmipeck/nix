{ lib, config, ... }:
let
  # The nix opencode subagent definition lives in the whole-tree package at
  # $out/agents/nix/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix.
  local = config.dotagents.localPackages;

  # `outPath` is a string in Nix 2.34; `/. +` rebuilds it as a true path so
  # home-manager's `agents` option copies the file via `source` (lib.isPath).
  store = /. + builtins.unsafeDiscardStringContext local.whole-tree.outPath;
in
{
  options.dotagents.agents.nix = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for nix (built from ../dotagents/agents/nix/agent.md).";
  };

  config.dotagents.agents.nix = lib.mkDefault (store + "/agents/nix/agent.md");
}
