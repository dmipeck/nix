_: {
  flake.homeModules.cli-tools =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        jq
        nodejs
        openssl
        python3
        uv
      ];
    };
}
