{ ... }:

{
  flake.vscodeModules.editorconfig = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      editorconfig.editorconfig
    ];
  };
}
