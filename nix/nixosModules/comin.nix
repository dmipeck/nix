{ inputs, ... }:

{
  flake.nixosModules.comin =
    { config, pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        sops
        age
      ];

      sops = {
        secrets."comin_access_token" = {
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
            url = "https://github.com/build13ltd/infra.git";
            branches.main.name = "main";
            auth.access_token_path = config.sops.secrets.comin_access_token.path;
          }
        ];
      };
    };
}
