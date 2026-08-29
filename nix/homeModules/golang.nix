{ ... }:

{
  flake.homeModules.golang =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        go
        gopls
      ];
    };
}
