{ inputs, ... }:

{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          editorconfig-checker
          gitleaks
          nixfmt
          pre-commit
        ];
        shellHook = ''
          pre-commit install --hook-type pre-commit --hook-type commit-msg
        '';
      };
    };

  systems = [ "x86_64-linux" ];
}
