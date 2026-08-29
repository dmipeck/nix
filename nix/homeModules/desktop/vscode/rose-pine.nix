{ ... }:

{
  flake.vscodeModules.rosePine = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      mvllow.rose-pine
    ];

    userSettings = {
      "workbench.colorTheme" = "Rosé Pine";
    };
  };
}
