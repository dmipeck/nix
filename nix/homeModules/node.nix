{ ... }:

{
  flake.homeModules.node =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        nodejs
      ];
    };
}
