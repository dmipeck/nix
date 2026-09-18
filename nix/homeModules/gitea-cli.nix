{
  sopsLib,
  ...
}:
{
  flake.homeModules.gitea-cli =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.gitea-cli;
      tokenPath = sopsLib.pathOrNull config cfg.sops "token";
      hostname =
        if cfg.host != null then
          lib.removePrefix "https://" (lib.removePrefix "http://" cfg.host)
        else
          null;
    in
    {
      options.programs.gitea-cli = {
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.tea;
          description = "The tea (Gitea CLI) package to install.";
        };

        host = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "https://gitea.build13.com";
          description = ''
            Gitea base URL written to ~/.config/tea/config.yml. When sops is
            disabled and the config file is absent, a login entry is seeded
            without a token (`tea login add` for interactive auth).
          '';
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = config.home.username;
          description = "Gitea username for the login entry.";
        };

        sops = lib.mkOption {
          type = sopsLib.mkType;
          default = { };
          description = ''
            Sops-backed secrets for tea. Gate with
            `programs.gitea-cli.sops.enable`, then set `secrets.token.key`.
            When enabled, activation rewrites ~/.config/tea/config.yml with
            the decrypted PAT each switch (after sops-nix has materialised
            the secret).
          '';
        };
      };

      config = {
        home.packages = [ cfg.package ];

        # sops-nix's HM hook restarts a oneshot without daemon-reload, so a
        # newly-added secret can leave systemd running the previous unit.
        # After linkGeneration: daemon-reload, restart sops-nix, wait, then
        # write tea config from the decrypted PAT.
        home.activation.giteaCliConfig = lib.mkIf (cfg.host != null) (
          lib.hm.dag.entryAfter ([ "linkGeneration" ] ++ lib.optional (tokenPath != null) "sops-nix") (
            if tokenPath != null then
              ''
                mkdir -p "$HOME/.config/tea"
                umask 077
                systemctl="${config.systemd.user.systemctlPath}"
                systemctlStatus="$($systemctl --user is-system-running 2>&1 || true)"
                if [[ $systemctlStatus == 'running' || $systemctlStatus == 'degraded' ]]; then
                  $systemctl daemon-reload --user
                  $systemctl restart --user sops-nix
                fi
                unset systemctlStatus
                token_file=${lib.escapeShellArg tokenPath}
                for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
                  if [ -f "$token_file" ]; then
                    break
                  fi
                  ${pkgs.coreutils}/bin/sleep 0.1
                done
                if [ ! -f "$token_file" ]; then
                  echo "gitea-cli: timed out waiting for sops secret at $token_file" >&2
                  exit 1
                fi
                token="$(${pkgs.coreutils}/bin/tr -d '\n' < "$token_file")"
                token_json="$(${pkgs.jq}/bin/jq -n --arg t "$token" '$t')"
                {
                  echo 'logins:'
                  echo '  - name: ${hostname}'
                  echo '    url: ${cfg.host}'
                  echo '    user: ${cfg.user}'
                  echo "    token: $token_json"
                  echo '    default: true'
                  echo 'preferences: {}'
                } > "$HOME/.config/tea/config.yml"
                ${pkgs.coreutils}/bin/chmod 600 "$HOME/.config/tea/config.yml"
              ''
            else
              ''
                mkdir -p "$HOME/.config/tea"
                umask 077
                if [ ! -f "$HOME/.config/tea/config.yml" ]; then
                  {
                    echo 'logins:'
                    echo '  - name: ${hostname}'
                    echo '    url: ${cfg.host}'
                    echo '    user: ${cfg.user}'
                    echo '    default: true'
                    echo 'preferences: {}'
                  } > "$HOME/.config/tea/config.yml"
                  ${pkgs.coreutils}/bin/chmod 600 "$HOME/.config/tea/config.yml"
                fi
              ''
          )
        );
      };
    };
}
