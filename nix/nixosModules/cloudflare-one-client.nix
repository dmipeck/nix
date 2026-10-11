# Cloudflare One Client (Zero Trust / WARP): the Operator-path connector to
# Cloudflare private network routes. Distinct from `cloudflared` Tunnel ingress.
#
# Enrollment is per-device and stays out-of-band:
#   warp-cli registration new <team>   # or: warp-cli teams-enroll
#   warp-cli connect
# See the infra runbook docs/runbooks/site-a-private-access-emc.md.
{
  flake.nixosModules.cloudflare-one-client =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.cloudflareOneClient;
    in
    {
      options.cloudflareOneClient = {
        enable = lib.mkEnableOption "Cloudflare One Client (Zero Trust WARP)";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.cloudflare-warp;
          defaultText = lib.literalExpression "pkgs.cloudflare-warp";
          description = "Package providing `warp-cli` and the `warp-svc` daemon.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.cloudflare-warp = {
          inherit (cfg) package;
          enable = true;
          openFirewall = true;
        };
      };
    };
}
