{ inputs, ... }:

{
  flake.homeModules.onlyoffice =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        onlyoffice-desktopeditors
      ];
    };
}
