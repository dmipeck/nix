{ lib, withSystem, ... }:
let
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # Multi-workspace Plane MCP (stdio). Not locked to one workspace — every
  # tool takes an explicit `workspace` slug. See github.com/dmipeck/plane-mcp.
  plane-mcp = pkgs.buildGoModule {
    pname = "plane-mcp";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "dmipeck";
      repo = "plane-mcp";
      rev = "v0.1.0";
      hash = "sha256-nonWNPunjJS/ADHBD96/YhMZCrpZ+sZhh4ogU/dn76w=";
    };
    vendorHash = "sha256-gKpXmBuFTVOoKZJ3wj1SzS261Fvp/r12u6FuDeCkcY4=";
    subPackages = [ "." ];
    ldflags = [
      "-s"
      "-w"
    ];
    meta = {
      description = "Multi-workspace Plane MCP server over stdio";
      homepage = "https://github.com/dmipeck/plane-mcp";
      mainProgram = "plane-mcp";
    };
  };

  readTools = [
    "project_list"
    "project_view"
    "state_list"
    "workitem_list"
    "workitem_view"
  ];

  writeTools = [
    "project_create"
    "project_update"
    "project_delete"
    "workitem_create"
    "workitem_update"
    "workitem_delete"
  ];
in
{
  config.dotagents.mcpPackages.plane-mcp = lib.mkDefault plane-mcp;

  # Tool enum only — Server Definition is in authored mcp.json.
  config.dotagents.mcpServers.plane = {
    _module.args.mcpToolEnum = lib.types.enum (readTools ++ writeTools);
    tools.read = readTools;
    tools.write = writeTools;
  };
}
