# Grok Bot desktop agent (https://x.ai/news/introducing-grok-bot).
# Official Linux amd64 .deb, vendored under nix/packages/grok-bot — not yet in
# nixpkgs (draft PR #558990); no well-supported community package to consume.
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
      # `_package.nix` — leading `/_` so import-tree skips the callPackage file.
      defaultPackage = pkgs.callPackage ../../packages/grok-bot/_package.nix { };
    in
    {
      options.programs.grok-bot = {
        enable = lib.mkEnableOption "the Grok Bot desktop agent";

        package = lib.mkOption {
          type = lib.types.package;
          default = defaultPackage;
          description = "The grok-bot package to install.";
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ cfg.package ];
      };
    };
}
