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

      packed = skillPackLib.packSkillRoot {
        inherit pkgs;
        pname = "skill-pack-fixture-flat";
        src = fixture;
        root = "flat";
        layout = "flat";
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
          ok = sortedEq packed.names [
            "alpha"
            "beta"
          ];
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;

      # Build-time: packed derivation must expose adapter layout paths.
      packCheck = pkgs.runCommand "skill-pack-layout" { } ''
        set -euo pipefail
        test -f ${packed.package}/skills/alpha/SKILL.md
        test -f ${packed.package}/skills/beta/SKILL.md
        test ! -e ${packed.package}/skills/empty-dir
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
