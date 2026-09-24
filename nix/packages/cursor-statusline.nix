# Expose pkgs.cursor-statusline via the library flake's packages output.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # `_package.nix` — leading `/_` so import-tree skips the callPackage file.
      packages.cursor-statusline = pkgs.callPackage ./cursor-statusline/_package.nix { };
    };
}
