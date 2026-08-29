{ inputs, ... }:

{
  flake.homeModules.headlamp =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      options = {
        headlamp.enable = lib.mkEnableOption "Enable Headlamp Kubernetes IDE";
      };

      config = lib.mkIf config.headlamp.enable {
        home.packages = with pkgs; [
          headlamp
        ];
      };
    };
}
