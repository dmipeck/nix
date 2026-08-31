{ lib, config, ... }:
let
  # The commit/test skill pair ships as dedicated bare-dir packages at
  # $out root (like git-workflow), and their opencode subagent definitions live
  # in the whole-tree package at $out/agents/<name>/agent.md — all built from
  # ../dotagents by nix/dotagents/local.nix.
  local = config.dotagents.localPackages;
in
{
  options.dotagents.skills = {
    commit = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for commit (local skill, built from ../dotagents/skills/commit).";
    };
    test = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for test (local skill, built from ../dotagents/skills/test).";
    };
  };

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
    dotagents.skills.commit = lib.mkDefault local.commit;
    dotagents.skills.test = lib.mkDefault local.test;
    dotagents.subagents.commit = lib.mkDefault "${local.whole-tree}/agents/commit/agent.md";
    dotagents.subagents.test = lib.mkDefault "${local.whole-tree}/agents/test/agent.md";
  };
}
