{ lib, config, ... }:
let
  # The commit/test skill pair ships as dedicated bare-dir packages at
  # $out root (like git-workflow), and their opencode subagent definitions live
  # in the whole-tree package at $out/agents/<name>.md — all built from ../ai
  # by nix/agents/local.nix.
  local = config.agents.localPackages;
in
{
  options.agents.skills = {
    commit = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for commit (local skill, built from ../ai/skills/commit).";
    };
    test = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for test (local skill, built from ../ai/skills/test).";
    };
  };

  options.agents.subagents = {
    commit = lib.mkOption {
      type = lib.types.path;
      description = "opencode subagent definition for commit (built from ../ai/agents/commit.md).";
    };
    test = lib.mkOption {
      type = lib.types.path;
      description = "opencode subagent definition for test (built from ../ai/agents/test.md).";
    };
  };

  config = {
    agents.skills.commit = lib.mkDefault local.commit;
    agents.skills.test = lib.mkDefault local.test;
    agents.subagents.commit = lib.mkDefault "${local.whole-tree}/agents/commit.md";
    agents.subagents.test = lib.mkDefault "${local.whole-tree}/agents/test.md";
  };
}
