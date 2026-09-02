{
  flake.homeModules.gitlab-cli =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.gitlab-cli;
    in
    {
      options.programs.gitlab-cli = {
        enable = lib.mkEnableOption "the glab GitLab CLI";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.glab;
          description = "The glab package to install.";
        };

        host = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "GitLab base URL, e.g. https://gitlab.example.com.";
        };

        tokenSopsKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Name of the sops-nix secret holding a GitLab personal access token.
            When set, glab is wrapped in a bash shim that reads the
            sops-decrypted file into GITLAB_TOKEN at runtime — the token value
            itself never lands in the Nix store, only the file path. Leave as
            null for a plain install without a token.
          '';
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = config.home.username;
          description = "GitLab username written to the glab config hosts entry.";
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages =
          if cfg.tokenSopsKey == null then
            [ cfg.package ]
          else
            [
              (pkgs.writeShellScriptBin "glab" ''
                # bash builtin read (no `cat` PATH dependency) of the
                # sops-decrypted PAT, exported to the env var glab reads.
                export GITLAB_TOKEN="$(<${config.sops.secrets.${cfg.tokenSopsKey}.path})"
                exec ${cfg.package}/bin/glab "$@"
              '')
            ];

        home.file.".config/glab-cli/config.yml".text =
          let
            hostname =
              if cfg.host != null then
                lib.removePrefix "https://" (lib.removePrefix "http://" cfg.host)
              else
                null;
          in
          ''
            git_protocol: https
            check_update: false
          ''
          + lib.optionalString (cfg.host != null) ''
            hosts:
              ${hostname}:
                git_protocol: https
                user: ${cfg.user}
          '';
      };
    };
}
