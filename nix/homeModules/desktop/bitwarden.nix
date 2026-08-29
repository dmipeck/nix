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

  flake.homeModules.bitwardenNixGL =
    { pkgs, config, ... }:
    let
      bitwardenNixGL = pkgs.symlinkJoin {
        name = "bitwarden-nixgl";
        paths = [ pkgs.bitwarden-desktop ];
        postBuild = ''
          rm -f "$out/bin/bitwarden"
          cat > "$out/bin/bitwarden" <<'EOF'
          #!${pkgs.runtimeShell}
          unset ELECTRON_RUN_AS_NODE
          exec ${pkgs.nixgl.nixGLMesa}/bin/nixGLMesa ${pkgs.bitwarden-desktop}/bin/bitwarden --disable-setuid-sandbox "$@"
          EOF
          chmod +x "$out/bin/bitwarden"
        '';
      };
    in
    {
      home.packages = with pkgs; [
        bitwardenNixGL
        bitwarden-cli
        chromium
      ];

      home.sessionVariables = {
        SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
        BITWARDEN_SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
      };
    };
}
