{
  lib,
  withSystem,
  inputs,
  ...
}:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The skill
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # https://github.com/JuliusBrussee/caveman — pinned as a flake=false input so
  # skill names are auto-discovered at eval time. Layout: skills/<name>/SKILL.md.
  # Non-skill entries (generated/, loose files) fall out via the SKILL.md test.
  cavemanSrc = inputs.caveman;

  skillDirs =
    root:
    builtins.attrNames (
      lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (root + "/" + name + "/SKILL.md")
      ) (builtins.readDir root)
    );

  skillNames = skillDirs (cavemanSrc + "/skills");

  cavemanPack = pkgs.runCommand "dotagents-caveman" { } ''
    mkdir -p $out/skills
    for d in ${cavemanSrc}/skills/*; do
      [ -f "$d/SKILL.md" ] || continue
      cp -rL "$d" "$out/skills/$(basename "$d")"
    done
  '';
in
{
  # Every skill dir shipped by the caveman repo is exposed by its own name; the
  # opencode/claude adapters slice each out of this package via $out/skills/<name>.
  config.dotagents.skills = lib.genAttrs skillNames (_: cavemanPack);
}
