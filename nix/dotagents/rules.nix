{ lib, ... }:
{
  options.dotagents.rules = lib.mkOption {
    type = lib.types.str;
    description = ''
      User-level global rules/instructions supplied to every agent at the start
      of a new session, read from ../dotagents/agents.md (the .agents protocol
      name for AGENTS.md-compatible guidelines).
    '';
  };

  config.dotagents.rules = lib.mkDefault (builtins.readFile ../../dotagents/agents.md);
}
