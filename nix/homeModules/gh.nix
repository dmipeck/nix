{
  flake.homeModules.gh =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.gh;
    in
    {
      options.programs.gh = {
        enable = lib.mkEnableOption "the GitHub CLI (gh)";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.gh;
          description = "The gh package to install.";
        };
      };

      config = lib.mkIf cfg.enable {
        # No PAT config: auth is interactive OAuth via `gh auth login`,
        # stored in gh's own config (~/.config/gh/hosts.yml). This module
        # only installs gh.
        home.packages = [ cfg.package ];
      };
    };
}
