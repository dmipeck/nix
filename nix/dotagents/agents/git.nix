{ lib, config, ... }:
let
  # The git opencode subagent definition lives in the whole-tree package at
  # $out/agents/git/agent.md, built from ../dotagents by nix/dotagents/local.nix.
  # It has read/write access to git: it runs any `git` command via bash to do
  # the git task asked of it.
  local = config.dotagents.localPackages;

  # `outPath` is a string in Nix 2.34; `/. +` rebuilds it as a true path so
  # home-manager's `agents` option copies the file via `source` (lib.isPath).
  store = /. + builtins.unsafeDiscardStringContext local.whole-tree.outPath;
in
{
  options.dotagents.agents.git = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for git (built from ../dotagents/agents/git/agent.md).";
  };

  config.dotagents.agents.git = lib.mkDefault (store + "/agents/git/agent.md");
}
