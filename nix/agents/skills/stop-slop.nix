{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The skill
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # https://github.com/hardikpandya/stop-slop — the repo root itself is the
  # skill (SKILL.md + references/), so subdir stays empty.
  stopSlopSrc = pkgs.fetchFromGitHub {
    owner = "hardikpandya";
    repo = "stop-slop";
    rev = "8da1f030185bdfe8471220585162991eaeb970e9";
    hash = "sha256-JMqlCRVEAfwG1TLMDpnamznkBfkmX6e2XyETTTH/TSE=";
  };
in
{
  options.agents.skills."stop-slop" = lib.mkOption {
    type = lib.types.package;
    description = "opencode skill package for stop-slop ($out/skills/stop-slop/SKILL.md).";
  };

  config.agents.skills."stop-slop" = lib.mkDefault (
    pkgs.runCommand "agents-stop-slop" { } ''
      mkdir -p $out/skills/stop-slop
      cp -rL ${stopSlopSrc}/. $out/skills/stop-slop/
    ''
  );
}
