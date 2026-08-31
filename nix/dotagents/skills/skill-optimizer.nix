{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The skill
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # https://github.com/hqhq1025/skill-optimizer — a three-skill toolkit
  # (skill-miner, skill-personalizer, skill-generalizer).
  skillOptimizerSrc = pkgs.fetchFromGitHub {
    owner = "hqhq1025";
    repo = "skill-optimizer";
    rev = "b9ffd1513e84136b72e2b6f041dc1ebfd9e23a84";
    hash = "sha256-bmlc9nD0Tz62sy+Grvt6ZWhuNQjk6AjuMy0aLPw+ZE8=";
  };
  skillOptimizerPack = pkgs.runCommand "dotagents-skill-optimizer" { } ''
    mkdir -p $out/skills
    cp -rL ${skillOptimizerSrc}/skills/skill-miner $out/skills/
    cp -rL ${skillOptimizerSrc}/skills/skill-personalizer $out/skills/
    cp -rL ${skillOptimizerSrc}/skills/skill-generalizer $out/skills/
  '';
in
{
  # Each of the three toolkit skills is exposed by its own name. The package
  # key itself (skill-optimizer) is NOT exposed: the package has no
  # $out/skills/skill-optimizer dir, and every config.dotagents.skills key is
  # rendered as $out/skills/<name> by the adapters.
  config.dotagents.skills = lib.genAttrs [
    "skill-generalizer"
    "skill-miner"
    "skill-personalizer"
  ] (_: skillOptimizerPack);
}
