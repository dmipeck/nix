{ lib, config, ... }:
{
  options.dotagents.commands.home-manager = lib.mkOption {
    type = lib.types.package;
    description = "opencode command file for home-manager (local command, built from ../dotagents/commands/home-manager.md).";
  };

  config.dotagents.commands.home-manager = lib.mkDefault config.dotagents.localPackages.home-manager;
}
