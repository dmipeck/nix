{
  inputs,
  lib,
  ...
}:

{
  flake.homeModules.git =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.git;

      oauthHostType = lib.types.submodule {
        options = {
          clientId = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              `credential.<url>.oauthClientId` for git-credential-oauth.
              Leave null to rely on the helper's built-in / auto-detected
              client (e.g. Gitea's default `git-credential-oauth` app on
              hosts named `gitea.*`).
            '';
          };
          clientSecret = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              `credential.<url>.oauthClientSecret`. Only needed for
              confidential OAuth apps; public native clients leave this null.
            '';
          };
          scopes = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Space-separated `credential.<url>.oauthScopes` (e.g.
              `"read_repository write_repository"`). Leave null for the
              helper default.
            '';
          };
          authURL = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Relative or absolute `credential.<url>.oauthAuthURL`.";
          };
          tokenURL = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Relative or absolute `credential.<url>.oauthTokenURL`.";
          };
          deviceAuthURL = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Relative or absolute `credential.<url>.oauthDeviceAuthURL`.";
          };
        };
      };

      oauthHostSettings = lib.mapAttrs (
        _url: host:
        lib.filterAttrs (_: v: v != null) {
          oauthClientId = host.clientId;
          oauthClientSecret = host.clientSecret;
          oauthScopes = host.scopes;
          oauthAuthURL = host.authURL;
          oauthTokenURL = host.tokenURL;
          oauthDeviceAuthURL = host.deviceAuthURL;
        }
      ) cfg.credentialOauth.hosts;
    in
    {
      options.git = {
        userName = lib.mkOption {
          type = lib.types.str;
          description = "Git commit author name (user.name).";
        };
        userEmail = lib.mkOption {
          type = lib.types.str;
          description = "Git commit author email (user.email).";
        };
        rewriteUrls = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            `url.<rewrite>.insteadOf` rules, mapping a remote URL prefix to the
            transport/URL used instead (e.g. force SSH over HTTPS for a private
            server).
          '';
        };
        goprivate = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Comma-separated GOPRIVATE pattern, exported as a session variable.
            Set for private Go module servers so go fetches them via VCS instead
            of the public module proxy. Leave null to omit the variable.
          '';
        };
        credentialOauth = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = cfg.credentialOauth.hosts != { };
            defaultText = lib.literalExpression "config.git.credentialOauth.hosts != { }";
            description = ''
              Install git-credential-oauth and wire `credential.helper` to
              cache then oauth (oauth last, so stored credentials are tried
              first). Defaults to true when any `hosts` entry is set.
            '';
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.git-credential-oauth;
            defaultText = lib.literalExpression "pkgs.git-credential-oauth";
            description = "git-credential-oauth package to install.";
          };
          cacheTimeout = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 21600;
            description = ''
              Seconds for `git-credential-cache` (storage helper that precedes
              oauth). Default is six hours, matching upstream's recommended
              config.
            '';
          };
          hosts = lib.mkOption {
            type = lib.types.attrsOf oauthHostType;
            default = { };
            example = {
              "https://gitea.example.com" = {
                clientId = "a4792ccc-144e-407e-86c9-5e7d8d9c3269";
              };
            };
            description = ''
              Per-URL `credential.<url>.*` settings for git-credential-oauth.
              Keys are HTTPS base URLs (e.g. `https://gitea.example.com`).
              Hosts that the helper auto-detects (including `gitea.*`) may omit
              every field; set `clientId` (and optionally scopes / endpoint
              URLs) when registering a custom OAuth app or documenting the
              expected public client.
            '';
          };
        };
      };

      config = {
        home.packages = lib.mkIf cfg.credentialOauth.enable [
          cfg.credentialOauth.package
        ];

        programs.git = {
          enable = true;
          lfs.enable = true;
          settings = {
            user = {
              name = cfg.userName;
              email = cfg.userEmail;
            };
            init.defaultBranch = "main";
            url = lib.mapAttrs' (
              rewrite: insteadOf: lib.nameValuePair rewrite { inherit insteadOf; }
            ) cfg.rewriteUrls;
            core.excludesFile = "~/.config/git/ignore";
          }
          // lib.optionalAttrs cfg.credentialOauth.enable {
            credential = {
              helper = [
                "cache --timeout ${toString cfg.credentialOauth.cacheTimeout}"
                "oauth"
              ];
            }
            // oauthHostSettings;
          };
          ignores = [
            "/.claude/"
            "/.direnv/"
            "/.kube/"
            "/.vscode/"
            "/.env"
            "/.envrc"
            "/result"
            "/result-*"
            "*.log"
          ];
        };

        home.sessionVariables = lib.mkIf (cfg.goprivate != null) {
          GOPRIVATE = cfg.goprivate;
        };
      };
    };
}
