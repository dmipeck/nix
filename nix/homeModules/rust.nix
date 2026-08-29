{ ... }:

{
  flake.homeModules.rust =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        cargo
        rustc
        rustfmt
        clippy
        rust-analyzer
      ];
    };
}
