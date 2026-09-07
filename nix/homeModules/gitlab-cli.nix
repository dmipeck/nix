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
      hostname =
        if cfg.host != null then
          lib.removePrefix "https://" (lib.removePrefix "http://" cfg.host)
        else
          null;
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

        user = lib.mkOption {
          type = lib.types.str;
          default = config.home.username;
          description = "GitLab username written to the glab config hosts entry.";
        };
      };

      config = lib.mkIf cfg.enable {
        # No PAT config: auth is interactive OAuth via `glab auth login`,
        # stored in glab's own config/keyring. This module only installs glab
        # and pre-seeds the host in config.yml.
        home.packages = [ cfg.package ];

        home.activation.gitlabCliConfig = lib.mkIf (cfg.host != null) (
          lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            mkdir -p "$HOME/.config/glab-cli"
            umask 077
            cat > "$HOME/.config/glab-cli/config.yml" <<'EOF'
            git_protocol: https
            check_update: false
            hosts:
              ${hostname}:
                git_protocol: https
                user: ${cfg.user}
            EOF
            chmod 600 "$HOME/.config/glab-cli/config.yml"
          ''
        );
      };
    };
}
