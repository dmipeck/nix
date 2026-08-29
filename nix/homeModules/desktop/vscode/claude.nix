{ ... }:

{
  flake.vscodeModules.claude = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      anthropic.claude-code
    ];

    userSettings = {
      "claudeCode.useTerminal" = true;
      "claudeCode.preferredLocation" = "panel";
    };
  };
}
