{ inputs, ... }:

{
  flake.homeModules.headlamp =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        headlamp
      ];
    };
}
