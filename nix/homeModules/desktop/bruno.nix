{ inputs, ... }:

{
  flake.homeModules.bruno =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        bruno
      ];
    };
}
