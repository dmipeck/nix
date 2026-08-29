{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The skill
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # https://github.com/mattpocock/skills — a skill collection; handoff and
  # grill-me each live in their own subdirectory under skills/productivity/.
  mattpocockSkillsSrc = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "6654f6b60cd9d5be8b54c6fafe44346dabeb3b76";
    hash = "sha256-N5tpUIHO2VFeJntBTl6/VLDIVpqoshwFxNJlfXXUwsQ=";
  };
  # Copy an upstream sub-directory into $out/skills/<name>, producing the
  # shared $out/skills/<name>/SKILL.md layout both Claude plugins and opencode
  # read.
  mkSkill =
    { name, subdir }:
    pkgs.runCommand "agents-${name}" { } ''
      mkdir -p $out/skills/${name}
      cp -rL ${mattpocockSkillsSrc}/${subdir}/. $out/skills/${name}/
    '';
in
{
  options.agents.skills = {
    "handoff" = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for handoff ($out/skills/handoff/SKILL.md).";
    };
    "grill-me" = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for grill-me ($out/skills/grill-me/SKILL.md).";
    };
  };

  config.agents.skills = {
    "handoff" = lib.mkDefault (mkSkill {
      name = "handoff";
      subdir = "skills/productivity/handoff";
    });
    "grill-me" = lib.mkDefault (mkSkill {
      name = "grill-me";
      subdir = "skills/productivity/grill-me";
    });
  };
}
