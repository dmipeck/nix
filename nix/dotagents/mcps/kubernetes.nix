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
  writeTools = [
    "apply-k8s-resource"
    "k8s-pod-exec"
  ];
in
{
  # Tool enum only — Server Definition in mcp.json; package via mcpPackages.
  # Server runs without --readonly so write tools exist; export-kubernetes
  # keeps an explicit read allowlist, kubernetes (write) opts into the full set.
  config.dotagents.mcpServers.kubernetes = {
    _module.args.mcpToolEnum = lib.types.enum (readTools ++ writeTools);
    tools.read = readTools;
    tools.write = writeTools;
  };
}
