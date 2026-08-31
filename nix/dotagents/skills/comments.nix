{ lib, config, ... }:
{
  options.dotagents.skills.comments = lib.mkOption {
    type = lib.types.package;
    description = "opencode skill package for comments (local skill, built from ../dotagents/skills/comments).";
  };

  config.dotagents.skills.comments = lib.mkDefault config.dotagents.localPackages.comments;
}
