{ inputs, ... }:
{
  flake.homeModules.sops =
    { pkgs, config, ... }:
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      home.packages = with pkgs; [
        sops
        age
      ];

      sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/key.txt";

      home.sessionVariables = {
        SOPS_AGE_KEY_FILE = "${config.sops.age.keyFile}";
      };
    };
}
