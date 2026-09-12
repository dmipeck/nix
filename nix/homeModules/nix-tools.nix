{ inputs, ... }:

{
  flake.homeModules.nix-tools =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        nixfmt
      ];
    };
}
