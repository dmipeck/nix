{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.invokeai = pkgs.callPackage ./invokeai/_package.nix { };
    };
}
