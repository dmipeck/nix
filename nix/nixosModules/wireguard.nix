{ inputs, ... }:

{
  flake.nixosModules.wireguard =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      options.wireguard = {
        enable = lib.mkEnableOption "Enable WireGuard module";
        build13 = {
          enable = lib.mkEnableOption "Enable Build13 WireGuard interface";
          clientIP = lib.mkOption {
            type = lib.types.str;
          };
          privateKeyFile = lib.mkOption {
            type = lib.types.str;
          };
        };
        littlemonkey = {
          enable = lib.mkEnableOption "Enable LittleMonkey WireGuard interface";
          clientIP = lib.mkOption {
            type = lib.types.str;
          };
          privateKeyFile = lib.mkOption {
            type = lib.types.str;
          };
        };
      };

      config.sops.secrets = {
        "build13_wireguard_private_key" = {
          owner = "root";
          group = "root";
          mode = "0400";
        };
        "littlemonkey_wireguard_private_key" = {
          owner = "root";
          group = "root";
          mode = "0400";
        };
      };

      config.networking.wireguard = {
        enable = config.wireguard.enable;

        interfaces = {
          "build13" = lib.mkIf config.wireguard.build13.enable {
            privateKeyFile = config.wireguard.build13.privateKeyFile;
            ips = [
              "${config.wireguard.build13.clientIP}/32"
            ];
            peers = [
              {
                publicKey = "T73AleG4m2TMz61vrCsdonUn5B29u1rWPJBrvi/IpGQ=";
                allowedIPs = [
                  "10.5.5.0/24"
                ];
                endpoint = "161.65.74.188:51820";
                persistentKeepalive = 25;
              }
            ];
          };

          "littlemonkey" = lib.mkIf config.wireguard.littlemonkey.enable {
            privateKeyFile = config.wireguard.littlemonkey.privateKeyFile;
            ips = [
              "${config.wireguard.littlemonkey.clientIP}/32"
            ];
            peers = [
              {
                publicKey = "1FCVUC9zujpPhXkk7f2vhz34Dcs9vNm9s6A3YxM4Rh4=";
                allowedIPs = [
                  "10.100.0.0/24"
                ];
                endpoint = "office.littlemonkey.co.nz:51828";
                persistentKeepalive = 25;
              }
            ];
          };
        };
      };

    };
}
