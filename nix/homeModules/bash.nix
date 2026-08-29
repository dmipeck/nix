{ inputs, ... }:

{
  flake.homeModules.bash =
    { pkgs, ... }:
    {
      programs.bash = {
        enable = true;
      };
    };
}
