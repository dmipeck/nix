{ lib, config, ... }:
{
  options.dotagents.commands.scaffold = lib.mkOption {
    type = lib.types.package;
    description = "opencode command file for scaffold (local command, built from ../dotagents/commands/scaffold.md).";
  };

  config.dotagents.commands.scaffold = lib.mkDefault config.dotagents.localPackages.scaffold;
}
