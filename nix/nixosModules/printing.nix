{ inputs, ... }:

{
  flake.nixosModules.printing =
    { pkgs, ... }:
    {
      services.printing.enable = true;
    };
}
