{ lib, ... }:
{
  options.dotagents.mcpServers = lib.mkOption {
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
          oauth = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  clientId = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Client ID of a pre-registered OAuth app for this remote MCP server.";
                  };
                  clientSecret = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = ''
                      OAuth client secret. May reference a secret file at runtime via
                      opencode's "{file:/abs/path}" substitution so the value never lands
                      in the Nix store. Servers without dynamic client registration
                      require this at authorization AND on every token refresh.
                    '';
                  };
                  scope = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Space-separated OAuth scopes to request during authorization.";
                  };
                };
              }
            );
            default = null;
            description = ''
              Pre-registered OAuth client config for a remote MCP server that does not
              support dynamic client registration (e.g. GitHub's hosted server at
              https://api.githubcopilot.com/mcp/). Only consumed by tools whose adapter
              renders an `oauth` block (opencode); other adapters ignore it.
            '';
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
