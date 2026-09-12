{
  inputs,
  lib,
  ...
}:

{
  flake.homeModules.wireguard-tools =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        wireguard-tools
      ];
    };
}
