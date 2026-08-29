{ inputs, ... }:

{
  flake.homeModules.direnv =
    { pkgs, ... }:
    {
      programs.direnv = {
        enable = true;
      };
    };
}
