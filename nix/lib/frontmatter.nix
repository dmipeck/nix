# Expose Frontmatter Parser to flake-parts modules via _module.args
# (same pattern as sopsLib).
{ lib, ... }:
{
  _module.args.frontmatterLib = import ./_frontmatter.nix { inherit lib; };
}
