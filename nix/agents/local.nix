{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The local content
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # Local AI content (skills/, commands/, agents/, rules/) lives in the repo
  # root ai/ dir; this module packages it into derivations for the adapters.
  ai = ../../ai;

  # Copy a whole skill dir (SKILL.md + references/) to $out root as a bare
  # dir, matching the historical per-skill package shape consumed by opencode
  # and claude (git-workflow, commit, test, thrifty, conventional-commits).
  bareSkill =
    name:
    pkgs.runCommand "agents-${name}" { } ''
      mkdir -p $out
      cp -rL ${ai}/skills/${name}/. $out/
    '';

  # The whole ai content tree (skills/ + commands/ + agents/) in one package;
  # the golang/postgres skills and the commit/test subagents are sliced
  # out by the adapters via $out/skills/<name> / $out/agents/<name>.md.
  wholeTree = pkgs.runCommand "agents" { } ''
    mkdir -p $out
    cp -r ${ai}/skills $out/skills
    cp -r ${ai}/commands $out/commands
    cp -r ${ai}/agents $out/agents
  '';
in
{
  options.agents.localPackages = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    description = "Local AI content packages built from ../ai (skills/, commands/, agents/).";
  };

  config.agents.localPackages = {
    git-workflow = bareSkill "git-workflow";
    conventional-commits = bareSkill "conventional-commits";
    thrifty = bareSkill "thrifty";
    commit = bareSkill "commit";
    test = bareSkill "test";
    comments = bareSkill "comments";
    whole-tree = wholeTree;

    # scaffold is a single command file, not a dir; the package output
    # is the file itself.
    scaffold = pkgs.runCommand "agents-scaffold" { } ''
      mkdir -p "$(dirname "$out")"
      cp ${ai}/commands/scaffold.md "$out"
    '';
  };
}
