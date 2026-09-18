# Stdio MCP package bindings — keyed by mcp.json command names. Server
# Definitions stay in authored mcp.json; Instance resolve rewrites commands
# to these store paths before Adapter Emit.
{ lib, withSystem, ... }:
let
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);
in
{
  config.dotagents.mcpPackages = {
    mcp-nixos = pkgs.mcp-nixos;
    playwright-mcp = pkgs.playwright-mcp;
    mcp-k8s-go = pkgs.mcp-k8s-go;
    mcp-grafana = pkgs.mcp-grafana;
    gitea-mcp = pkgs.gitea-mcp-server;
    firebase = pkgs.firebase-tools;
  };
}
