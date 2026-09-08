{
  flake.homeModules.copilot =
    {
      pkgs,
      ...
    }:
    {
      # No sops PAT wiring: Copilot CLI authenticates via `copilot login`
      # (interactive OAuth), stored in its own config.
      home.packages = with pkgs; [
        github-copilot-cli
      ];
    };
}
