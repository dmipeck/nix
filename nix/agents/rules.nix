{ lib, inputs, ... }:
{
  options.agents.rules = lib.mkOption {
    type = lib.types.str;
    description = ''
      User-level global rules/instructions supplied to every agent at the start
      of a new session, read from dmipeck/agents rules/rules.md.
    '';
  };

  config.agents.rules = lib.mkDefault (builtins.readFile "${inputs.agents.outPath}/rules/rules.md");
}
