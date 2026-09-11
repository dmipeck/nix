# Expose pkgs.grok-bot via the library flake's packages output.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # `_package.nix` — leading `/_` so import-tree skips the callPackage file.
      packages.grok-bot = pkgs.callPackage ./grok-bot/_package.nix { };
    };
}
