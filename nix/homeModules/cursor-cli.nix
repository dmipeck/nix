{
  flake.homeModules.cursor-cli =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.cursor-cli;
    in
    {
      options.programs.cursor-cli = {
        enable = lib.mkEnableOption "the Cursor CLI (cursor-agent)";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.cursor-cli;
          description = "The cursor-cli package to install.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Auth is interactive via `cursor-agent auth` (or CURSOR_API_KEY),
        # stored in the CLI's own config. This module only installs the CLI.
        home.packages = [ cfg.package ];

        home.shellAliases.cursor = "cursor-agent";
      };
    };
}
