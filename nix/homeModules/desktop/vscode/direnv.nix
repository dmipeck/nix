{ ... }:

{
  flake.vscodeModules.direnv = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      mkhl.direnv
    ];
  };
}
