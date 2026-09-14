# Tool-enum + package bindings for MCP servers. Server Definitions live in
# authored dotagents/mcp.json (Cursor wire shape); these Nix modules only
# validate tool allowlists and bind stdio binaries to store paths.
{ lib, ... }:
{
  options.dotagents.mcpServers = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        let
          serverEnum = config._module.args.mcpToolEnum;
        in
        {
          config._module.args.mcpToolEnum = lib.mkDefault (lib.types.enum [ ]);
          options = {
            tools = lib.mkOption {
              type = lib.types.submodule (
                { config, ... }:
                {
                  options.read = lib.mkOption {
                    type = lib.types.listOf serverEnum;
                    default = [ ];
                    description = "Read-only tools to allow without prompting.";
                  };
                  options.write = lib.mkOption {
                    type = lib.types.listOf serverEnum;
                    default = [ ];
                    description = "Mutating tools, to prompt/ask before running.";
                  };
                  options.all = lib.mkOption {
                    type = lib.types.listOf serverEnum;
                    default = config.read ++ config.write;
                    description = "All tools the server exposes (read + write).";
                  };
                }
              );
              default = { };
              description = "Per-server tool allowlists, validated against the server's tool enum.";
            };
          };
        }
      )
    );
    default = { };
    description = ''
      Nix-side MCP tool enums / allowlists. Server Definitions (command, url,
      headers, env) live in authored mcp.json; Instance overlays live under
      homeModules/dotagents.nix.
    '';
  };

  options.dotagents.mcpPackages = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    default = { };
    description = ''
      Stdio MCP server packages keyed by the binary name used in mcp.json
      (e.g. mcp-nixos, argocd-mcp). Instance resolve rewrites authored command
      names to store paths before Adapter Emit.
    '';
  };
}
