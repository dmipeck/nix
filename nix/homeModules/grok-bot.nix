{
  flake.homeModules.grok-bot =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.grok-bot;
    in
    {
      options.programs.grok-bot = {
        enable = lib.mkEnableOption "the Grok Build CLI (grok)";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.grok-build;
          description = "The grok-build package to install.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Auth is interactive on first launch (browser OAuth), stored in the
        # CLI's own config. This module only installs the package.
        home.packages = [ cfg.package ];
      };
    };
}
