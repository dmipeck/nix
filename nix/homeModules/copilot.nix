{
  inputs,
  lib,
  ...
}:

{
  flake.homeModules.copilot =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      options.copilot = {
        githubTokenSopsKey = lib.mkOption {
          type = lib.types.str;
          description = "Name of the sops-nix secret holding the GitHub token for Copilot CLI.";
        };
      };

      config = {
        home.packages = with pkgs; [
          github-copilot-cli
        ];

        sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/key.txt";

        home.sessionVariables = {
          COPILOT_GITHUB_TOKEN = "$(cat ${config.sops.secrets.${config.copilot.githubTokenSopsKey}.path})";
        };
      };
    };
}
