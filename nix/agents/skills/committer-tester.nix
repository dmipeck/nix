{ lib, config, ... }:
let
  # The committer/tester skill pair ships as dedicated bare-dir packages at
  # $out root (like git-workflow), and their opencode subagent definitions live
  # in the whole-tree package at $out/agents/<name>.md — all built from ../ai
  # by nix/agents/local.nix.
  local = config.agents.localPackages;
in
{
  options.agents.skills = {
    committer = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for committer (local skill, built from ../ai/skills/committer).";
    };
    tester = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for tester (local skill, built from ../ai/skills/tester).";
    };
  };

  options.agents.subagents = {
    committer = lib.mkOption {
      type = lib.types.path;
      description = "opencode subagent definition for committer (built from ../ai/agents/committer.md).";
    };
    tester = lib.mkOption {
      type = lib.types.path;
      description = "opencode subagent definition for tester (built from ../ai/agents/tester.md).";
    };
  };

  config = {
    agents.skills.committer = lib.mkDefault local.committer;
    agents.skills.tester = lib.mkDefault local.tester;
    agents.subagents.committer = lib.mkDefault "${local.whole-tree}/agents/committer.md";
    agents.subagents.tester = lib.mkDefault "${local.whole-tree}/agents/tester.md";
  };
}
