_: {
  flake.homeModules.dnstools =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        dnsutils
      ];
    };
}
