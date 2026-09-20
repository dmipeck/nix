{
  lib,
  withSystem,
  inputs,
  ...
}:
let
  plane-mcp = withSystem "x86_64-linux" (
    { system, ... }: inputs.plane-mcp.packages.${system}.default
  );

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
