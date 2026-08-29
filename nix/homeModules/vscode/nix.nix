{ ... }:

{
  flake.vscodeModules.nix = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
      arrterian.nix-env-selector
    ];
  };
}
