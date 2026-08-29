{ lib, ... }:
{
  options.agents.mcpServers = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          type = lib.mkOption {
            type = lib.types.enum [
              "local"
              "remote"
            ];
          };
          command = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          args = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          env = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
          };
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          headers = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
          };
          readOnlyTools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Read-only tools to allow without prompting.";
          };
          writableTools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Mutating tools, to prompt/ask before running.";
          };
        };
      }
    );
    description = "Neutral MCP server configs, consumed by each AI tool's adapter.";
  };
}
