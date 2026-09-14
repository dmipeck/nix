# Common Model MCP — authored dotagents/mcp.json is the single SoT for Server
# Definitions (Cursor wire shape). Instance overlays apply in homeModules;
# tool enums stay on Nix modules under nix/dotagents/mcps/.
{
  lib,
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
      headers / auth / env), loaded from authored mcp.json via importJSON.
      MCP Instance overlays (enable, URL, sops, package resolve) apply before
      Adapter Emit. Tool enums stay on Nix modules, not here.
    '';
  };

  config = {
    _module.args.mcpLib = mcpLib;
    dotagents.commonModel.mcpServers = authored;
  };
}
