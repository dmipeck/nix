{ inputs, ... }:

{
  flake.homeModules.nix-tools =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      options = {
        nix-tools.enable = lib.mkEnableOption "Enable Nix Tools";
      };

      config = lib.mkIf config.nix-tools.enable {
        home.packages = with pkgs; [
          nixfmt
        ];
      };
    };
}
