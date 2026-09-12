{
  inputs,
  lib,
  ...
}:

{
  flake.homeModules.clockify =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        clockify
      ];
    };
}
