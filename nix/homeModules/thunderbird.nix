{ inputs, ... }:

{
  flake.homeModules.thunderbird =
    { pkgs, ... }:
    {
      programs.thunderbird.enable = true;
    };
}
