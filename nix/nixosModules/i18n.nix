{
  inputs,
  lib,
  ...
}:

{
  flake.nixosModules.i18n =
    { config, lib, ... }:
    let
      cfg = config.i18nConfig;
    in
    {
      options.i18nConfig.locale = lib.mkOption {
        type = lib.types.str;
        description = "System locale, applied to both i18n.defaultLocale and all LC_* categories.";
      };

      config = lib.mkIf (cfg.locale != "") {
        i18n.defaultLocale = cfg.locale;

        i18n.extraLocaleSettings = {
          LC_ADDRESS = cfg.locale;
          LC_IDENTIFICATION = cfg.locale;
          LC_MEASUREMENT = cfg.locale;
          LC_MONETARY = cfg.locale;
          LC_NAME = cfg.locale;
          LC_NUMERIC = cfg.locale;
          LC_PAPER = cfg.locale;
          LC_TELEPHONE = cfg.locale;
          LC_TIME = cfg.locale;
        };
      };
    };
}
