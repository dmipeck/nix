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
    pkgs.runCommand "agents-grafana-${group}" { } ''
      mkdir -p $out/skills
      cp -rL ${grafanaSkillsSrc}/skills/${group}/. $out/skills/
    '';
in
{
  options.agents.skills = {
    "grafana-core" = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for grafana-core ($out/skills/).";
    };
    "grafana-lgtm" = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for grafana-lgtm ($out/skills/).";
    };
    "grafana-datasources" = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for grafana-datasources ($out/skills/).";
    };
  };

  config.agents.skills = {
    "grafana-core" = lib.mkDefault (mkGrafanaGroup "grafana-core");
    "grafana-lgtm" = lib.mkDefault (mkGrafanaGroup "grafana-lgtm");
    "grafana-datasources" = lib.mkDefault (mkGrafanaGroup "grafana-datasources");
  };
}
