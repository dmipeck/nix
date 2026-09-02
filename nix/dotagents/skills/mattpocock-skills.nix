{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The skill
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # https://github.com/mattpocock/skills — a skill collection; each skill
  # lives in its own subdirectory under skills/<category>/.
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
    pkgs.runCommand "dotagents-${name}" { } ''
      mkdir -p $out/skills/${name}
      cp -rL ${mattpocockSkillsSrc}/${subdir}/. $out/skills/${name}/
    '';
in
{
  config.dotagents.skills =
    let
      # name → upstream subdir. grill-me, grill-with-docs, wayfinder are
      # user-invoked trampolines; grilling, domain-modeling, research,
      # prototype are the model-invoked skills they dispatch to;
      # setup-matt-pocock-skills bootstraps the per-repo config wayfinder
      # reads.
      skills = {
        handoff = "skills/productivity/handoff";
        grill-me = "skills/productivity/grill-me";
        grill-with-docs = "skills/engineering/grill-with-docs";
        wayfinder = "skills/engineering/wayfinder";
        grilling = "skills/productivity/grilling";
        domain-modeling = "skills/engineering/domain-modeling";
        research = "skills/engineering/research";
        prototype = "skills/engineering/prototype";
        setup-matt-pocock-skills = "skills/engineering/setup-matt-pocock-skills";
      };
    in
    lib.mapAttrs (name: subdir: mkSkill { inherit name subdir; }) skills;
}
