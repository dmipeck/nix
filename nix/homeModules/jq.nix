{ ... }:

{
  flake.homeModules.jq =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        jq
      ];
    };
}
