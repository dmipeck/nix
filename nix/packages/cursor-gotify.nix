# Expose pkgs.cursor-gotify via the library flake's packages output.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # `_package.nix` — leading `/_` so import-tree skips the callPackage file.
      packages.cursor-gotify = pkgs.callPackage ./cursor-gotify/_package.nix { };
    };
}
