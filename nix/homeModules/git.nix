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
      };

      config = {
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
