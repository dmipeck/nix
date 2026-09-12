{ sopsLib, ... }:

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
      accessTokenPath = sopsLib.pathOrNull config cfg.sops "accessToken";
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
        sops = lib.mkOption {
          type = sopsLib.mkType;
          default = {
            enable = true;
            secrets.accessToken.key = "comin_access_token";
          };
          description = ''
            Sops-backed secrets for comin. Gate with `comin.sops.enable`, then
            set `comin.sops.secrets.accessToken.key` (sops-nix secret name) and
            optionally `comin.sops.secrets.accessToken.keyFile` (path override).
          '';
        };
      };

      config = {
        assertions = [
          {
            assertion = accessTokenPath != null;
            message = ''
              comin requires a repository access token: set
              comin.sops.enable = true and
              comin.sops.secrets.accessToken.key (or .keyFile).
            '';
          }
        ];

        environment.systemPackages = with pkgs; [
          sops
          age
        ];

        sops.secrets =
          lib.mkIf
            (sopsLib.secretConfigured cfg.sops "accessToken" && cfg.sops.secrets.accessToken.keyFile == null)
            {
              ${cfg.sops.secrets.accessToken.key} = {
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
              auth.access_token_path = accessTokenPath;
            }
          ];
        };
      };
    };
}
