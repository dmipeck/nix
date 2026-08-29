{ inputs, ... }:

{
  flake.homeModules.littlemonkey =
    { config, pkgs, ... }:
    {
      home.packages = with pkgs; [
        clockify
        wireguard-tools
      ];
    };
}
