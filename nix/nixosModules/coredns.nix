{
  inputs,
  lib,
  ...
}:

{
  flake.nixosModules.coredns =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.coredns;
    in
    {
      options.coredns = {
        hosts = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                ip = lib.mkOption {
                  type = lib.types.str;
                  description = "IP address for the hostnames below.";
                };
                names = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Hostnames (with or without domain) mapping to the IP.";
                };
              };
            }
          );
          default = [ ];
          description = "Static A records served by the `hosts` plugin.";
        };
        upstream = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "8.8.8.8"
            "8.8.4.4"
          ];
          description = "Upstream resolvers for non-local queries (forward plugin).";
        };
      };

      config = {
        services.coredns = {
          enable = true;
          config =
            lib.concatStringsSep "\n" (
              [
                ". {"
                "  hosts {"
              ]
              ++ map (e: "    ${e.ip} ${lib.concatStringsSep " " e.names}") cfg.hosts
              ++ [
                "    fallthrough"
                "  }"
                ""
                "  forward . ${lib.concatStringsSep " " cfg.upstream} {"
                "    max_concurrent 1000"
                "  }"
                ""
                "  cache 30"
                "  errors"
                "  log"
                "}"
              ]
            )
            + "\n";
        };

        networking.firewall.allowedUDPPorts = [ 53 ];
        networking.firewall.allowedTCPPorts = [ 53 ];
      };
    };
}
