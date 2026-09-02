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

  # https://github.com/hardikpandya/stop-slop — the repo root itself is the
  # skill (SKILL.md + references/). Pinned as a flake=false input.
  stopSlopSrc = inputs.stop-slop;
in
{
  config.dotagents.skills = lib.genAttrs [ "stop-slop" ] (
    _:
    pkgs.runCommand "dotagents-stop-slop" { } ''
      mkdir -p $out/skills/stop-slop
      cp -rL ${stopSlopSrc}/. $out/skills/stop-slop/
    ''
  );
}
