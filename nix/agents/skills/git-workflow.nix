{ lib, inputs, ... }:
{
  options.agents.skills.git-workflow = lib.mkOption {
    type = lib.types.package;
    description = "opencode skill package for git-workflow (local skill, built by dmipeck/agents).";
  };

  config.agents.skills.git-workflow = lib.mkDefault inputs.agents.packages.x86_64-linux.git-workflow;
}
