{ lib, config, ... }:
{
  options.agents.commands.scaffold = lib.mkOption {
    type = lib.types.package;
    description = "opencode command file for scaffold (local command, built from ../ai/commands/scaffold.md).";
  };

  config.agents.commands.scaffold = lib.mkDefault config.agents.localPackages.scaffold;
}
