{ inputs, ... }:

{
  flake.homeModules.postman =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        postman
      ];
    };
}
