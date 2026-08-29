{ inputs, ... }:

{
  flake.homeModules.krita =
    { config, pkgs, ... }:
    {
      home.packages = with pkgs; [
        krita
      ];
    };
}
