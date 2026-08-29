{ inputs, ... }:

{
  flake.homeModules.git =
    { pkgs, ... }:
    {
      programs.git = {
        enable = true;
        lfs.enable = true;
        settings = {
          user = {
            name = "David Peck";
            email = "git@dmipeck.com";
          };
          init.defaultBranch = "main";
          url."ssh://git@gitlab.littlemonkey.co.nz:2222/".insteadOf = "https://gitlab.littlemonkey.co.nz/";
        };
        ignores = [
          "/.claude/"
          "/.direnv/"
          "/.kube/"
          "/.vscode/"
          "/.env"
          "/.envrc"
          "/result"
          "/result-*"
          "*.log"
        ];
      };

      # Go treats gitlab.littlemonkey.co.nz as private, fetching modules directly
      # via VCS (over the SSH insteadOf rewrite above) instead of the public
      # module proxy/checksum database.
      home.sessionVariables = {
        GOPRIVATE = "gitlab.littlemonkey.co.nz/*";
      };
    };
}
