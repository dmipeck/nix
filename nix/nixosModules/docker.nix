{ inputs, ... }:

{
  flake.nixosModules.docker =
    { pkgs, ... }:
    {
      virtualisation.docker.enable = true;
    };
}
