{
  inputs,
  lib,
  ...
}:

{
  flake.nixosModules.wireguard =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.wireguard;
    in
    {
      options.wireguard = {
        enable = lib.mkEnableOption "Enable WireGuard module";

        interfaces = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                privateKeyFile = lib.mkOption {
                  type = lib.types.str;
                  description = "Path to the interface's WireGuard private key (e.g. a sops-decrypted secret).";
                };
                address = lib.mkOption {
                  type = lib.types.str;
                  description = "CIDR address assigned to this interface (e.g. \"10.0.0.2/32\").";
                };
                peers = lib.mkOption {
                  type = lib.types.listOf (
                    lib.types.submodule {
                      options = {
                        publicKey = lib.mkOption {
                          type = lib.types.str;
                        };
                        allowedIPs = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                        };
                        endpoint = lib.mkOption {
                          type = lib.types.str;
                        };
                        persistentKeepalive = lib.mkOption {
                          type = lib.types.int;
                          default = 25;
                        };
                      };
                    }
                  );
                  description = "Peer endpoints this interface connects to.";
                };
              };
            }
          );
          default = { };
          description = "WireGuard interfaces, keyed by interface name.";
        };
      };

      config.networking.wireguard = {
        enable = cfg.enable;

        interfaces = lib.mapAttrs' (
          name: iface:
          lib.nameValuePair name {
            privateKeyFile = iface.privateKeyFile;
            ips = [ iface.address ];
            peers = map (peer: {
              inherit (peer)
                publicKey
                allowedIPs
                endpoint
                persistentKeepalive
                ;
            }) iface.peers;
          }
        ) cfg.interfaces;
      };
    };
}
