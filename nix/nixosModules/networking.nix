{ inputs, ... }:

{
  flake.nixosModules.networking =
    { lib, config, ... }:
    {
      options.clusterNetworking = {
        enable = lib.mkEnableOption "cluster networking";
        nameservers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
        };
        searchDomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
      };

      config = lib.mkIf config.clusterNetworking.enable {
        services.openssh.enable = true;
        services.resolved.enable = true;
        networking.useNetworkd = true;
        networking.nameservers = config.clusterNetworking.nameservers;
        networking.search = config.clusterNetworking.searchDomains;
      };
    };
}
