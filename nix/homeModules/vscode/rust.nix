{ ... }:

{
  flake.vscodeModules.rust = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      rust-lang.rust-analyzer
    ];
  };
}
