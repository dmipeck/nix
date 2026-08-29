{ inputs, ... }:

{
  flake.homeModules.zulip =
    { config, pkgs, ... }:
    {
      home.packages = with pkgs; [
        zulip
      ];
    };
}
