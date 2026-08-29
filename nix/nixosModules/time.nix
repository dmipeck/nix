{ inputs, ... }:

{
  flake.nixosModules.time =
    { pkgs, ... }:
    {
      time.timeZone = "Pacific/Auckland";
    };
}
