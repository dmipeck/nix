{ lib, config, ... }:
let
  # The explore-git opencode subagent definition lives in the whole-tree
  # package at $out/agents/explore-git/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix. It is a read-only git observer: it runs only
  # `git` commands via bash and never mutates.
  local = config.dotagents.localPackages;

  # `outPath` is a string in Nix 2.34; `/. +` rebuilds it as a true path so
  # home-manager's `agents` option copies the file via `source` (lib.isPath).
  store = /. + builtins.unsafeDiscardStringContext local.whole-tree.outPath;
in
{
  options.dotagents.subagents."explore-git" = lib.mkOption {
    type = lib.types.path;
    description = "opencode subagent definition for explore-git (built from ../dotagents/agents/explore-git/agent.md).";
  };

  config.dotagents.subagents."explore-git" = lib.mkDefault (store + "/agents/explore-git/agent.md");
}
