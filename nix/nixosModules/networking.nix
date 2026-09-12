{ inputs, ... }:

{
  flake.nixosModules.networking =
    { lib, config, ... }:
    {
      options.clusterNetworking = {
        nameservers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
        };
        searchDomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
      };

      config = {
        services.openssh.enable = true;
        services.resolved.enable = true;
        networking.useNetworkd = true;
        networking.nameservers = config.clusterNetworking.nameservers;
        networking.search = config.clusterNetworking.searchDomains;
      };
    };
}
