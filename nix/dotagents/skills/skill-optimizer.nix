{
  lib,
  withSystem,
  inputs,
  skillPackLib,
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
  packed = skillPackLib.packSkillRoot {
    inherit pkgs;
    pname = "dotagents-skill-optimizer";
    src = inputs.skill-optimizer;
    root = "skills";
    layout = "flat";
  };

  # Whole-bundle key for claude (renders the package root as one plugin);
  # constituent skills are exposed individually for opencode.
  keys = packed.names ++ lib.optional (!lib.elem "skill-optimizer" packed.names) "skill-optimizer";
in
{
  config.dotagents.skills = lib.genAttrs keys (_: packed.package);
  config.dotagents.skillLayouts."skill-optimizer" = "collection";
}
