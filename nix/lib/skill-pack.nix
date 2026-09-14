# Expose skill pack discovery helpers to flake-parts modules via
# `_module.args.skillPackLib` (same pattern as frontmatterLib / sopsLib).
{ lib, ... }:
{
  _module.args.skillPackLib = import ./_skill-pack.nix { inherit lib; };
}
