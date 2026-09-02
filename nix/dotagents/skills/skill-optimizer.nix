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

  # https://github.com/hqhq1025/skill-optimizer — pinned as a flake=false input;
  # the toolkit skills are auto-discovered at eval time. Layout:
  # skills/<name>/SKILL.md.
  skillOptimizerSrc = inputs.skill-optimizer;

  skillDirs =
    root:
    builtins.attrNames (
      lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (root + "/" + name + "/SKILL.md")
      ) (builtins.readDir root)
    );

  skillNames = skillDirs (skillOptimizerSrc + "/skills");

  skillOptimizerPack = pkgs.runCommand "dotagents-skill-optimizer" { } ''
    mkdir -p $out/skills
    for d in ${skillOptimizerSrc}/skills/*; do
      [ -f "$d/SKILL.md" ] || continue
      cp -rL "$d" "$out/skills/$(basename "$d")"
    done
  '';

  # Whole-bundle key for claude (renders the package root as one plugin);
  # constituent skills are exposed individually for opencode.
  keys = skillNames ++ lib.optional (!lib.elem "skill-optimizer" skillNames) "skill-optimizer";
in
{
  config.dotagents.skills = lib.genAttrs keys (_: skillOptimizerPack);
  config.dotagents.skillLayouts."skill-optimizer" = "collection";
}
