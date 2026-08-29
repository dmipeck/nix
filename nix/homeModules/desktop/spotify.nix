{ inputs, ... }:

{
  flake.homeModules.spotify =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        spotify
      ];
    };

  flake.homeModules.spotifyNixGL =
    { pkgs, config, ... }:
    {
      home.packages = with pkgs; [
        (config.lib.nixGL.wrap spotify)
      ];
    };
}
