{ lib, ... }:
let
  readTools = [
    "get-k8s-pod-logs"
    "get-k8s-resource"
    "list-k8s-contexts"
    "list-k8s-events"
    "list-k8s-namespaces"
    "list-k8s-nodes"
    "list-k8s-resources"
  ];
in
{
  # Tool enum only — Server Definition in mcp.json; package via mcpPackages.
  config.dotagents.mcpServers.kubernetes = {
    _module.args.mcpToolEnum = lib.types.enum readTools;
    tools.read = readTools;
  };
}
