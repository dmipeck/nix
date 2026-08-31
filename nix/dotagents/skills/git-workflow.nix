{ lib, config, ... }:
{
  options.dotagents.skills.git-workflow = lib.mkOption {
    type = lib.types.package;
    description = "opencode skill package for git-workflow (local skill, built from ../dotagents/skills/git-workflow).";
  };

  config.dotagents.skills.git-workflow = lib.mkDefault config.dotagents.localPackages.git-workflow;
}
