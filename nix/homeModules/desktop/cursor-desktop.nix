{ inputs, ... }:

{
  flake.homeModules.cursor-desktop =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        code-cursor
      ];
    };
}
