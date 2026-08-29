{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem, mirroring the
  # skills modules. The package is a nixpkgs derivation; evaluation stays lazy
  # until a consumer forces it.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);
in
{
  config.agents.mcpServers.nixos = {
    type = "local";
    command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    readOnlyTools = [ ];
  };
}
