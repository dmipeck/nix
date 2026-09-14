# Expose Adapter Emit helpers via _module.args.adapterEmit.
{
  lib,
  frontmatterLib,
  ...
}:
{
  _module.args.adapterEmit = import ./_emit.nix {
    inherit lib frontmatterLib;
  };
}
