{ ... }:

{
  flake.homeModules.openssl =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        openssl
      ];
    };
}
