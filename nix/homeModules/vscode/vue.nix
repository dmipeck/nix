{ ... }:

{
  flake.vscodeModules.vue = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      vue.volar
    ];
  };
}
