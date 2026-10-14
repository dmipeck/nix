{ inputs, ... }:

{
  flake.homeModules.bitwarden =
    { pkgs, config, ... }:
    {
      home.packages = with pkgs; [
        bitwarden-desktop
        bitwarden-cli
      ];

      home.sessionVariables = {
        SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
        BITWARDEN_SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
      };
    };
}
