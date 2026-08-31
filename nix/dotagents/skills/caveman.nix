{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The skill
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # https://github.com/JuliusBrussee/caveman — the whole skills/ tree (every
  # subdirectory containing a SKILL.md), mirroring the grafana group packaging
  # above. Non-skill files (compile.mjs, generated/, ...) are skipped by the
  # SKILL.md test.
  cavemanSrc = pkgs.fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "17f9f2ec2377b0bfe16b52ee03a462e7f0a02bc8";
    hash = "sha256-lmzmlPj47lWNRZudMSsdIocS4srZYQeG2bQw800Os7U=";
  };
  cavemanPack = pkgs.runCommand "dotagents-caveman" { } ''
    mkdir -p $out/skills
    for d in ${cavemanSrc}/skills/*; do
      [ -f "$d/SKILL.md" ] || continue
      cp -rL "$d" "$out/skills/$(basename "$d")"
    done
  '';
in
{
  options.dotagents.skills."caveman" = lib.mkOption {
    type = lib.types.package;
    description = "opencode skill package for caveman ($out/skills/).";
  };

  config.dotagents.skills."caveman" = lib.mkDefault cavemanPack;
}
