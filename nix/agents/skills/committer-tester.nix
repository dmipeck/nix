{ lib, inputs, ... }:
let
  # The committer/tester skill pair ships as dedicated bare-dir packages at
  # $out root (like git-workflow), and their opencode subagent definitions live
  # in the whole-tree `agents` package at $out/agents/<name>.md.
  committer = inputs.agents.packages.x86_64-linux.committer;
  tester = inputs.agents.packages.x86_64-linux.tester;
  agentsPkg = inputs.agents.packages.x86_64-linux.agents;
in
{
  options.agents.skills = {
    committer = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for committer (local skill, built by dmipeck/agents).";
    };
    tester = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for tester (local skill, built by dmipeck/agents).";
    };
  };

  options.agents.subagents = {
    committer = lib.mkOption {
      type = lib.types.path;
      description = "opencode subagent definition for committer (built by dmipeck/agents).";
    };
    tester = lib.mkOption {
      type = lib.types.path;
      description = "opencode subagent definition for tester (built by dmipeck/agents).";
    };
  };

  config = {
    agents.skills.committer = lib.mkDefault committer;
    agents.skills.tester = lib.mkDefault tester;
    agents.subagents.committer = lib.mkDefault "${agentsPkg}/agents/committer.md";
    agents.subagents.tester = lib.mkDefault "${agentsPkg}/agents/tester.md";
  };
}
