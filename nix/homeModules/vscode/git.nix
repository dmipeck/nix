{ ... }:

{
  flake.vscodeModules.git = pkgs: {
    userSettings = {
      "scm.defaultViewMode" = "tree";
      "git.suggestSmartCommit" = false;
    };
  };
}
