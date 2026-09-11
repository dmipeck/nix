# Expose pkgs.grok-bot via the library flake's packages output.
{ inputs, ... }:
{
  perSystem =
    {
      system,
      lib,
      ...
    }:
    let
      # Unfree desktop .deb — flake check / `nix build .#grok-bot` need an
      # explicit allow (CI runs plain `nix flake check` with no env). Scope the
      # predicate to this pname so the rest of the flake stays free-default.
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: lib.getName pkg == "grok-bot";
      };
    in
    {
      # `_package.nix` — leading `/_` so import-tree skips the callPackage file.
      packages.grok-bot = pkgs.callPackage ./grok-bot/_package.nix { };
    };
}
