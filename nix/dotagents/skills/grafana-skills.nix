{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The skill
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # https://github.com/grafana/skills — a marketplace of skill groups, each a
  # subdirectory of skills/<group>/. Builds $out/skills/<name>/SKILL.md per
  # skill; Claude auto-discovers skills with no plugin manifest needed,
  # opencode reads $out/skills/<name>.
  grafanaSkillsSrc = pkgs.fetchFromGitHub {
    owner = "grafana";
    repo = "skills";
    rev = "51d33e71e191b409bbd25fc7be2684c610d18166";
    hash = "sha256-13pDO69zgLkDjJ49O/8a4ncmm6MTppAhDK8wioELpwY=";
  };
  mkGrafanaGroup =
    group:
    pkgs.runCommand "dotagents-grafana-${group}" { } ''
      mkdir -p $out/skills
      cp -rL ${grafanaSkillsSrc}/skills/${group}/. $out/skills/
    '';
in
{
  # Every skill dir in each grafana group is exposed by its own name. The
  # group/package keys (grafana-core, grafana-lgtm, grafana-datasources) are
  # whole bundles whose $out/skills/ contains the many constituent skills;
  # they are exposed too and marked layout "collection" so adapters render
  # the package root (claude: whole plugin) or skip it (opencode: no
  # single-skill form).
  config.dotagents.skills =
    lib.genAttrs [
      "alerting-irm"
      "alloy"
      "beyla"
      "dashboarding"
      "grafana-core"
      "grafana-oss"
      "opentelemetry"
      "promql"
      "skill-authoring"
    ] (_: mkGrafanaGroup "grafana-core")
    // lib.genAttrs [
      "grafana-lgtm"
      "loki"
      "mimir"
      "prometheus"
      "pyroscope"
      "tempo"
    ] (_: mkGrafanaGroup "grafana-lgtm")
    // lib.genAttrs [ "datasources-provisioning" "grafana-datasources" ] (
      _: mkGrafanaGroup "grafana-datasources"
    );

  config.dotagents.skillLayouts = {
    grafana-core = "collection";
    grafana-lgtm = "collection";
    grafana-datasources = "collection";
  };
}
