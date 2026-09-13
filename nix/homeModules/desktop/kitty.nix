{ inputs, ... }:

let
  font = {
    name = "JetBrainsMono NF";
    size = 12;
  };

  settings = {
    foreground = "#e0def4";
    background = "#191724";
    selection_foreground = "#e0def4";
    selection_background = "#403d52";

    cursor = "#524f67";
    cursor_text_color = "#e0def4";

    url_color = "#c4a7e7";

    active_tab_foreground = "#e0def4";
    active_tab_background = "#26233a";
    inactive_tab_foreground = "#6e6a86";
    inactive_tab_background = "#191724";

    active_border_color = "#31748f";
    inactive_border_color = "#403d52";

    # black
    color0 = "#26233a";
    color8 = "#6e6a86";

    # red
    color1 = "#eb6f92";
    color9 = "#eb6f92";

    # green
    color2 = "#31748f";
    color10 = "#31748f";

    # yellow
    color3 = "#f6c177";
    color11 = "#f6c177";

    # blue
    color4 = "#9ccfd8";
    color12 = "#9ccfd8";

    # magenta
    color5 = "#c4a7e7";
    color13 = "#c4a7e7";

    # cyan
    color6 = "#ebbcba";
    color14 = "#ebbcba";

    # white
    color7 = "#e0def4";
    color15 = "#e0def4";

    # GNOME/Mutter has no SSD — kitty must draw its own CSD to keep
    # window buttons. Distinct surface color so the bar reads as chrome.
    # (Titlebar height/padding is hardcoded in kitty's Wayland CSD — not
    # configurable via kitty.conf.)
    wayland_titlebar_color = "#26233a";
  };
in
{
  flake.homeModules.kitty =
    { pkgs, ... }:
    {
      fonts.fontconfig.enable = true;

      home.packages = [
        pkgs.nerd-fonts.jetbrains-mono
      ];

      programs.kitty = {
        enable = true;
        inherit font settings;
      };
    };

  flake.homeModules.kittyNixGL =
    { pkgs, config, ... }:
    {
      fonts.fontconfig.enable = true;

      home.packages = [
        pkgs.nerd-fonts.jetbrains-mono
      ];

      programs.kitty = {
        enable = true;
        package = config.lib.nixGL.wrap pkgs.kitty;
        inherit font settings;
      };
    };
}
