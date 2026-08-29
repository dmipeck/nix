{ inputs, ... }:

{
  flake.homeModules.discord =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        discord
      ];
    };
}
