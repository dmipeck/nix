{
  inputs,
  lib,
  ...
}:

{
  flake.nixosModules.time =
    { config, lib, ... }:
    {
      options.timeConfig.timeZone = lib.mkOption {
        type = lib.types.str;
        description = "System timezone (IANA name, e.g. \"UTC\").";
      };

      config.time.timeZone = config.timeConfig.timeZone;
    };
}
