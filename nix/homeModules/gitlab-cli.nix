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

      # Per-host entry lines for the glab config.yml hosts map. Optional
      # keys (container_registry_domains, client_id) are only emitted when
      # configured.
      hostEntry = lib.concatStringsSep "\n" (
        [
          "  ${hostname}:"
          "    git_protocol: https"
          "    user: ${cfg.user}"
        ]
        ++ lib.optional (
          cfg.containerRegistryDomains != [ ]
        ) "    container_registry_domains: ${lib.concatStringsSep "," cfg.containerRegistryDomains}"
        ++ lib.optional (cfg.clientId != null) "    client_id: ${cfg.clientId}"
      );

      glabConfigYaml = ''
        git_protocol: https
        check_update: false
        hosts:
        ${hostEntry}
      '';
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

        containerRegistryDomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Container registry domains for this host, written to the glab
            config hosts entry as container_registry_domains (comma-separated).
            Used by the Docker credential helper (glab auth configure-docker).
          '';
        };

        clientId = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            OAuth client_id (Application ID) for glab auth login against this
            host. Register the OAuth app with redirect
            http://localhost:7171/auth/redirect and scopes openid profile
            read_user write_repository api (Confidential NOT selected).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # No PAT config: auth is interactive OAuth via `glab auth login`,
        # stored in glab's own config/keyring. This module only installs glab
        # and pre-seeds the host (plus container registry domains and OAuth
        # client_id when configured) in config.yml.
        home.packages = [ cfg.package ];

        home.activation.gitlabCliConfig = lib.mkIf (cfg.host != null) (
          lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            mkdir -p "$HOME/.config/glab-cli"
            umask 077
            cat > "$HOME/.config/glab-cli/config.yml" <<'EOF'
            ${glabConfigYaml}
            EOF
            chmod 600 "$HOME/.config/glab-cli/config.yml"
          ''
        );
      };
    };
}
