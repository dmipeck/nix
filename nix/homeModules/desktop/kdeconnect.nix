{ inputs, ... }:

{
  flake.homeModules.kdeconnect =
    { pkgs, ... }:
    {
      services.kdeconnect.enable = true;
    };
}
