{
  flake.homeModules.gh =
    { ... }:
    {
      # home-manager already declares programs.gh.*; do not redeclare.
      # Auth is interactive OAuth via `gh auth login` (~/.config/gh/hosts.yml).
      programs.gh.enable = true;
    };
}
