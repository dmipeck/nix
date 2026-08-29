{
  inputs,
  lib,
  ...
}:

{
  flake.homeModules.clockify =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      options.clockify.enable = lib.mkEnableOption "Clockify time tracking";

      config = lib.mkIf config.clockify.enable {
        home.packages = with pkgs; [
          clockify
        ];
      };
    };
}
