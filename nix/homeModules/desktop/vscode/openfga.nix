{ ... }:

{
  flake.vscodeModules.openfga = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      openfga.openfga-vscode
    ];
  };
}
