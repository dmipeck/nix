{ lib, config, ... }:
let
  # The commit/test opencode subagent definitions live in the whole-tree
  # package at $out/agents/<name>/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix.
  local = config.dotagents.localPackages;

  # `outPath` is a string in Nix 2.34; `/. +` rebuilds it as a true path so
  # home-manager's `agents` option copies the file via `source` (lib.isPath).
  store = /. + builtins.unsafeDiscardStringContext local.whole-tree.outPath;
in
{
  options.dotagents.agents = {
    commit = lib.mkOption {
      type = lib.types.path;
      description = "opencode agent definition for commit (built from ../dotagents/agents/commit/agent.md).";
    };
    test = lib.mkOption {
      type = lib.types.path;
      description = "opencode agent definition for test (built from ../dotagents/agents/test/agent.md).";
    };
  };

  config = {
    dotagents.agents.commit = lib.mkDefault (store + "/agents/commit/agent.md");
    dotagents.agents.test = lib.mkDefault (store + "/agents/test/agent.md");
  };
}
