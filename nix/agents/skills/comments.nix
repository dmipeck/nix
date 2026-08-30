{ lib, config, ... }:
{
  options.agents.skills.comments = lib.mkOption {
    type = lib.types.package;
    description = "opencode skill package for comments (local skill, built from ../ai/skills/comments).";
  };

  config.agents.skills.comments = lib.mkDefault config.agents.localPackages.comments;
}
