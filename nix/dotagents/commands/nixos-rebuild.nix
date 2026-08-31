{ lib, config, ... }:
{
  options.dotagents.commands.nixos-rebuild = lib.mkOption {
    type = lib.types.package;
    description = "opencode command file for nixos-rebuild (local command, built from ../dotagents/commands/nixos-rebuild.md).";
  };

  config.dotagents.commands.nixos-rebuild = lib.mkDefault config.dotagents.localPackages.nixos-rebuild;
}
