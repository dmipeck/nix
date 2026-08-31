{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem, mirroring the
  # skills modules. The package is a nixpkgs derivation; evaluation stays lazy
  # until a consumer forces it.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);
in
{
  config.dotagents.mcpServers.kubernetes = {
    type = "local";
    command = "${pkgs.mcp-k8s-go}/bin/mcp-k8s-go";
    readOnlyTools = [
      "get-k8s-pod-logs"
      "get-k8s-resource"
      "list-k8s-contexts"
      "list-k8s-events"
      "list-k8s-namespaces"
      "list-k8s-nodes"
      "list-k8s-resources"
    ];
  };
}
