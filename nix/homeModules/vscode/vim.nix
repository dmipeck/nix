{ ... }:

{
  flake.vscodeModules.vim = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      vscodevim.vim
    ];
  };
}
