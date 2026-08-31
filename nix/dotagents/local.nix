{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The local content
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # Local AI content (skills/, commands/, agents/, agents.md global rules)
  # lives in the repo root dotagents/ dir (following the .agents protocol
  # layout); this module packages it into derivations for the adapters.
  dotagents = ../../dotagents;

  # Copy a whole skill dir (SKILL.md + references/) to $out root as a bare
  # dir, matching the historical per-skill package shape consumed by opencode
  # and claude (git-workflow, thrifty, conventional-commits, comments).
  bareSkill =
    name:
    pkgs.runCommand "dotagents-${name}" { } ''
      mkdir -p $out
      cp -rL ${dotagents}/skills/${name}/. $out/
    '';

  # The whole dotagents content tree (skills/ + commands/ + agents/) in one
  # package; the golang/postgres skills and the commit/test subagents are
  # sliced out by the adapters via $out/skills/<name> /
  # $out/agents/<name>/agent.md.
  wholeTree = pkgs.runCommand "dotagents" { } ''
    mkdir -p $out
    cp -r ${dotagents}/skills $out/skills
    cp -r ${dotagents}/commands $out/commands
    cp -r ${dotagents}/agents $out/agents
  '';
in
{
  options.dotagents.localPackages = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    description = "Local AI content packages built from ../dotagents (skills/, commands/, agents/).";
  };

  config.dotagents.localPackages = {
    git-workflow = bareSkill "git-workflow";
    conventional-commits = bareSkill "conventional-commits";
    thrifty = bareSkill "thrifty";
    comments = bareSkill "comments";
    whole-tree = wholeTree;

    # scaffold is a single command file, not a dir; the package output is the
    # file itself.
    scaffold = pkgs.runCommand "dotagents-scaffold" { } ''
      mkdir -p "$(dirname "$out")"
      cp ${dotagents}/commands/scaffold.md "$out"
    '';
  };
}
