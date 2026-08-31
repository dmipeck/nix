{ lib, config, ... }:
let
  # The commit/test opencode subagent definitions live in the whole-tree
  # package at $out/agents/<name>/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix.
  local = config.dotagents.localPackages;
in
{
  options.dotagents.subagents = {
    commit = lib.mkOption {
      type = lib.types.path;
      description = "opencode subagent definition for commit (built from ../dotagents/agents/commit/agent.md).";
    };
    test = lib.mkOption {
      type = lib.types.path;
      description = "opencode subagent definition for test (built from ../dotagents/agents/test/agent.md).";
    };
  };

  config = {
    dotagents.subagents.commit = lib.mkDefault "${local.whole-tree}/agents/commit/agent.md";
    dotagents.subagents.test = lib.mkDefault "${local.whole-tree}/agents/test/agent.md";
  };
}
