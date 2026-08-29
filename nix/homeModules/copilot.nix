{ inputs, ... }:

{
  flake.homeModules.copilot =
    { pkgs, config, ... }:
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      home.packages = with pkgs; [
        github-copilot-cli
      ];

      sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/key.txt";

      home.sessionVariables = {
        COPILOT_GITHUB_TOKEN = "$(cat ${config.sops.secrets."github_copilot_token".path})";
      };
    };
}
