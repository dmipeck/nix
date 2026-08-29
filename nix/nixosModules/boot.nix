{ inputs, ... }:

{
  flake.nixosModules.boot =
    { config, pkgs, ... }:
    {
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = 8;
      };
      boot.loader.efi.canTouchEfiVariables = true;
    };
}
