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

      # A glab wrapper: a small bash shim that reads a sops-decrypted PAT file
      # into GITLAB_TOKEN at runtime (and GITLAB_HOST when `host` is set), then
      # execs the real glab — the token value itself never lands in the Nix
      # store, only the file path. Shared by the read-only `glab` wrapper and
      # the read-write `glab-rw` wrapper so the two shims stay identical in
      # shape.
      mkWrapper =
        binaryName: secretKey:
        pkgs.writeShellScriptBin binaryName ''
          # bash builtin read (no `cat` PATH dependency) of the
          # sops-decrypted PAT, exported to the env var glab reads.
          export GITLAB_TOKEN="$(<${config.sops.secrets.${secretKey}.path})"
          ${lib.optionalString (cfg.host != null) "export GITLAB_HOST=\"${hostname}\""}
          exec ${cfg.package}/bin/glab "$@"
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

        readWriteTokenSopsKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Name of the sops-nix secret holding a GitLab personal access token
            with WRITE scopes. When set, an additional wrapper binary
            `glab-rw` is installed that reads the sops-decrypted file into
            GITLAB_TOKEN at runtime (and GITLAB_HOST when `host` is set, same
            as the main wrapper) — the token value itself never lands in the
            Nix store, only the file path. Leave as null for no read-write
            wrapper. Keeps write access out of the read-only `glab` wrapper's
            token.
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
          let
            # A wrapper per configured token: `glab` from tokenSopsKey (the
            # existing read-only wrapper, unchanged), `glab-rw` from
            # readWriteTokenSopsKey. No wrappers at all -> the plain package.
            wrappers =
              lib.optional (cfg.tokenSopsKey != null) (mkWrapper "glab" cfg.tokenSopsKey)
              ++ lib.optional (cfg.readWriteTokenSopsKey != null) (mkWrapper "glab-rw" cfg.readWriteTokenSopsKey);
          in
          if wrappers == [ ] then [ cfg.package ] else wrappers;

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
