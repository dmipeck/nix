{ ... }:

{
  flake.vscodeModules.yaml = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      redhat.vscode-yaml
    ];
  };
}
