{ inputs, ... }:

{
  flake.nixosModules.steam =
    { pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        extest.enable = true;
        extraCompatPackages = [ pkgs.proton-ge-bin ];
      };
    };
}
