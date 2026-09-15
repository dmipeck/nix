# Skill pack discovery/pack seam — fixture Authoring Format skill trees →
# discovered skill keys + packed $out/skills/<id>/SKILL.md. Asserts external
# behavior only (which keys exist; dirs without SKILL.md ignored; pack layout).
{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      skillPackLib = import ../lib/_skill-pack.nix { inherit lib; };

      fixture = ../dotagents/fixtures/skill-pack;

      flatNames = map (s: s.name) (
        skillPackLib.discoverSkills {
          root = fixture + "/flat";
          layout = "flat";
        }
      );
      recursiveNames = map (s: s.name) (
        skillPackLib.discoverSkills {
          root = fixture + "/recursive";
          layout = "recursive";
        }
      );

      packedFlat = skillPackLib.packSkillRoot {
        inherit pkgs;
        pname = "skill-pack-fixture-flat";
        src = fixture;
        root = "flat";
        layout = "flat";
      };

      packedRecursive = skillPackLib.packSkillRoot {
        inherit pkgs;
        pname = "skill-pack-fixture-recursive";
        src = fixture;
        root = "recursive";
        layout = "recursive";
      };

      sortedEq = a: b: (lib.sort builtins.lessThan a) == (lib.sort builtins.lessThan b);

      assertions = [
        {
          name = "flat-discovers-skill-md-dirs";
          ok = sortedEq flatNames [
            "alpha"
            "beta"
          ];
        }
        {
          name = "flat-ignores-non-skill-siblings";
          ok = !(builtins.elem "empty-dir" flatNames) && !(builtins.elem "notes.txt" flatNames);
        }
        {
          name = "recursive-discovers-nested-skill-md";
          ok = sortedEq recursiveNames [
            "alpha"
            "gamma"
          ];
        }
        {
          name = "recursive-ignores-shared-and-docs";
          ok = !(builtins.elem "shared" recursiveNames) && !(builtins.elem "docs" recursiveNames);
        }
        {
          name = "pack-skill-root-names";
          ok = sortedEq packedFlat.names [
            "alpha"
            "beta"
          ];
        }
        {
          name = "pack-recursive-names-exclude-non-skills";
          ok = sortedEq packedRecursive.names [
            "alpha"
            "gamma"
          ];
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;

      # Build-time: packed derivation must expose adapter layout paths and keep
      # non-skill siblings (shared/, docs/) in the tree — not as skill keys.
      packCheck = pkgs.runCommand "skill-pack-layout" { } ''
        set -euo pipefail
        test -f ${packedFlat.package}/skills/alpha/SKILL.md
        test -f ${packedFlat.package}/skills/beta/SKILL.md
        test ! -e ${packedFlat.package}/skills/empty-dir
        test -f ${packedRecursive.package}/skills/alpha/SKILL.md
        test -f ${packedRecursive.package}/skills/gamma/SKILL.md
        test -f ${packedRecursive.package}/skills/shared/helper.md
        test -f ${packedRecursive.package}/skills/docs/README.md
        test ! -e ${packedRecursive.package}/skills/shared/SKILL.md
        echo "skill-pack layout OK" > "$out"
      '';
    in
    {
      checks.skill-pack =
        if failures != [ ] then
          throw ("skill-pack mismatches: " + lib.concatMapStringsSep ", " (a: a.name) failures)
        else
          packCheck;
    };
}
