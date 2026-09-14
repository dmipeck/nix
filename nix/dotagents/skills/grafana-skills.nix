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

  # https://github.com/grafana/skills — pinned as a flake=false input; every
  # group under skills/ and every skill inside each group is auto-discovered at
  # eval time. Upstream layout: skills/<group>/<skill>/SKILL.md.
  grafanaSkillsSrc = inputs.grafana-skills;

  inherit (skillPackLib) listDirs skillDirs;

  # Groups that actually contain skills become whole-bundle (collection) keys.
  groupNames = listDirs (grafanaSkillsSrc + "/skills");
  groups = lib.filter (g: skillDirs (grafanaSkillsSrc + "/skills/" + g) != [ ]) groupNames;

  # Build a derivation whose $out/skills/ holds every skill of one group.
  mkGrafanaGroup =
    group:
    pkgs.runCommand "dotagents-grafana-${group}" { } ''
      mkdir -p $out/skills
      cp -rL ${grafanaSkillsSrc}/skills/${group}/. $out/skills/
    '';

  skillKeys = builtins.concatMap (
    group:
    map (name: lib.nameValuePair name (mkGrafanaGroup group)) (
      skillDirs (grafanaSkillsSrc + "/skills/" + group)
    )
  ) groups;
in
{
  config.dotagents.skills =
    builtins.listToAttrs skillKeys // lib.genAttrs groups (group: mkGrafanaGroup group);

  # Whole-bundle keys: adapters render the package root (claude: whole plugin)
  # or skip it (opencode: no single-skill form).
  config.dotagents.skillLayouts = lib.genAttrs groups (group: "collection");
}
