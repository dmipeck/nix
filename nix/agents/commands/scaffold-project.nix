{ lib, config, ... }:
{
  options.agents.commands.scaffold-project = lib.mkOption {
    type = lib.types.package;
    description = "opencode command file for scaffold-project (local command, built from ../ai/commands/scaffold-project.md).";
  };

  config.agents.commands.scaffold-project = lib.mkDefault config.agents.localPackages.scaffold-project;
}
