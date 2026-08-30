{ lib, ... }:
{
  options.agents.rules = lib.mkOption {
    type = lib.types.str;
    description = ''
      User-level global rules/instructions supplied to every agent at the start
      of a new session, read from ../ai/rules/rules.md.
    '';
  };

  config.agents.rules = lib.mkDefault (builtins.readFile ../../ai/rules/rules.md);
}
