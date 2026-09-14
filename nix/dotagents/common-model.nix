# Common Model MCP — dual-read authored dotagents/mcp.json with Nix Server
# Definition modules (mcps/*.nix). Instance overlays apply via mcpLib;
# adapters still consume config.dotagents.mcpServers until the emit flip (#66).
{
  lib,
  config,
  ...
}:
let
  mcpLib = import ./_mcp.nix { inherit lib; };
  authoredPath = ../../dotagents/mcp.json;
  authored = mcpLib.importMcpJson authoredPath;
in
{
  options.dotagents.commonModel.mcpServers = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    description = ''
      Common Model MCP Server Definitions in Cursor wire shape (stdio / url /
      headers / auth / env). Dual-read from authored mcp.json and legacy Nix
      modules under nix/dotagents/mcps/; Nix overlays the same keys so existing
      Server Definitions keep working during migration. Tool enums stay on the
      Nix modules, not here.
    '';
  };

  config = {
    _module.args.mcpLib = mcpLib;
    dotagents.commonModel.mcpServers = mcpLib.dualReadMcpServers {
      inherit authored;
      nixServers = config.dotagents.mcpServers;
    };
  };
}
