{
  inputs,
  lib,
  ...
}:

{
  flake.homeModules.wireguard-tools =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      options.wireguard-tools.enable = lib.mkEnableOption "WireGuard tools (wg / wg-quick)";

      config = lib.mkIf config.wireguard-tools.enable {
        home.packages = with pkgs; [
          wireguard-tools
        ];
      };
    };
}
