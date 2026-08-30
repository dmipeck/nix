{ lib, config, ... }:
{
  options.agents.skills.git-workflow = lib.mkOption {
    type = lib.types.package;
    description = "opencode skill package for git-workflow (local skill, built from ../ai/skills/git-workflow).";
  };

  config.agents.skills.git-workflow = lib.mkDefault config.agents.localPackages.git-workflow;
}
