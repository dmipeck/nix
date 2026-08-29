{ inputs, ... }:
{
  flake.nixosModules.sops =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      options.sops = {
        sopsFile = lib.mkOption {
          type = lib.types.path;
        };
        ageKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "/root/.config/sops/age/key.txt";
        };
      };

      config.sops = {
        defaultSopsFile = config.sops.sopsFile;
        age.keyFile = config.sops.ageKeyFile;
      };
    };
}
