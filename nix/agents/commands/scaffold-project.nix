{ lib, inputs, ... }:
{
  options.agents.commands.scaffold-project = lib.mkOption {
    type = lib.types.package;
    description = "opencode command file for scaffold-project (local command, built by dmipeck/agents).";
  };

  config.agents.commands.scaffold-project = lib.mkDefault inputs.agents.packages.x86_64-linux.scaffold-project;
}
