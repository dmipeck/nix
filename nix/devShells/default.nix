{ inputs, ... }:

{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          deadnix
          editorconfig-checker
          gitleaks
          nixd
          nixfmt # RFC 166 style (merged nixfmt-rfc-style; use pkgs.nixfmt)
          pre-commit
          statix
        ];
        shellHook = ''
          pre-commit install --hook-type pre-commit --hook-type commit-msg
        '';
      };
    };

  systems = [ "x86_64-linux" ];
}
