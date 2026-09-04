{ inputs, ... }:

{
  flake.homeModules.tmux =
    { pkgs, lib, ... }:
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

      # System-clipboard integration for Linux. `tmux-copy` prefers Wayland
      # (wl-copy) and falls back to X11 (xclip); without either it discards
      # the selection so the bindings still behave. Not installed elsewhere.
      home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        (pkgs.writeShellScriptBin "tmux-copy" ''
          if [ -n "$WAYLAND_DISPLAY" ]; then
            exec ${pkgs.wl-clipboard}/bin/wl-copy
          elif [ -n "$DISPLAY" ]; then
            exec ${pkgs.xclip}/bin/xclip -selection clipboard
          else
            exec cat > /dev/null
          fi
        '')
        pkgs.wl-clipboard
        pkgs.xclip
      ];
    };
}
