{
  inputs,
  lib,
  ...
}:

{
  flake.nixosModules.comin =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.comin;
    in
    {
      options.comin = {
        repoUrl = lib.mkOption {
          type = lib.types.str;
          description = "Git remote URL comin polls for configuration updates.";
        };
        branch = lib.mkOption {
          type = lib.types.str;
          default = "main";
          description = "Branch of the repository to track.";
        };
        accessTokenSopsKey = lib.mkOption {
          type = lib.types.str;
          default = "comin_access_token";
          description = "Name of the sops-nix secret holding the repository access token.";
        };
      };

      config = {
        environment.systemPackages = with pkgs; [
          sops
          age
        ];

        sops = {
          secrets.${cfg.accessTokenSopsKey} = {
            owner = "root";
            group = "root";
            mode = "0400";
          };
        };

        services.comin = {
          enable = true;
          remotes = [
            {
              name = "origin";
              url = cfg.repoUrl;
              branches.${cfg.branch}.name = cfg.branch;
              auth.access_token_path = config.sops.secrets.${cfg.accessTokenSopsKey}.path;
            }
          ];
        };
      };
    };
}
