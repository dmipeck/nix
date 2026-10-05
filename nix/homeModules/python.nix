{ ... }:

{
  flake.homeModules.python =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        python3
        uv
      ];
    };
}
