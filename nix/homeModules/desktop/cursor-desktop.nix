{ inputs, ... }:

{
  flake.homeModules.cursor-desktop =
    { lib, pkgs, ... }:
    let
      # Free the `cursor` name for the CLI; desktop is invoked as cursor-desktop.
      cursorDesktop = pkgs.symlinkJoin {
        name = "cursor-desktop";
        paths = [ pkgs.code-cursor ];
        postBuild = ''
          rm -f "$out/bin/cursor"
          ln -s ${lib.getExe' pkgs.code-cursor "cursor"} "$out/bin/cursor-desktop"

          rm -rf "$out/share/applications"
          mkdir -p "$out/share/applications"
          for f in ${pkgs.code-cursor}/share/applications/*.desktop; do
            ${pkgs.gnused}/bin/sed \
              -e 's/^Exec=cursor /Exec=cursor-desktop /' \
              -e 's/^Exec=cursor$/Exec=cursor-desktop/' \
              "$f" > "$out/share/applications/$(basename "$f")"
          done
        '';
      };
    in
    {
      home.packages = [ cursorDesktop ];
    };
}
