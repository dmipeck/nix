{ inputs, ... }:

{
  flake.homeModules.starship =
    { pkgs, ... }:
    {
      programs.starship = {
        enable = true;
        presets = [
          "nerd-font-symbols"
        ];
      };
    };
}
