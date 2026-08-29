{ inputs, ... }:

{
  flake.homeModules.tmux =
    { pkgs, ... }:
    {
      programs.tmux = {
        enable = true;
        mouse = true;
        keyMode = "vi";
        baseIndex = 1;
        historyLimit = 10000;
        terminal = "tmux-256color";
        escapeTime = 0;
        extraConfig = builtins.readFile ./tmux.conf;
      };
    };
}
