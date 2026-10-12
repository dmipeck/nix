{
  sopsLib,
  ...
}:
{
  flake.homeModules.linode-cli =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.linode-cli;
      tokenPath = sopsLib.pathOrNull config cfg.sops "token";

      wrapped = pkgs.symlinkJoin {
        name = "linode-cli";
        paths = [ cfg.package ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/linode-cli \
            --run 'export LINODE_CLI_TOKEN="$(${pkgs.coreutils}/bin/tr -d "\n" < ${lib.escapeShellArg tokenPath})"'
        '';
      };
    in
    {
      options.programs.linode-cli = {
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.linode-cli;
          description = "The linode-cli package to install.";
        };

        sops = lib.mkOption {
          type = sopsLib.mkType;
          default = { };
          description = ''
            Sops-backed Linode PAT. Gate with
            `programs.linode-cli.sops.enable`, then set `secrets.token.key`.
            When enabled, the installed `linode-cli` wrapper exports
            `LINODE_CLI_TOKEN` from the decrypted secret on each invocation.
          '';
        };
      };

      config = {
        assertions = [
          {
            assertion = !cfg.sops.enable || tokenPath != null;
            message = "programs.linode-cli.sops.enable requires secrets.token.key or secrets.token.keyFile";
          }
        ];

        home.packages = [ (if tokenPath != null then wrapped else cfg.package) ];
      };
    };
}
