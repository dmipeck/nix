# Merge-skill-catalog seam — pure attr merge (no HM adapters, no network).
# Asserts: source skills appear; disabled sources omit; library∪source
# duplicates abort; collection filter still skips collection keys.
# Full adapter fixture graph is #79 (out of scope here).
{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      mergeLib = import ../homeModules/_merge-skill-catalog.nix { inherit lib; };

      # Stand-in packages (paths only — adapters only need attr names + values).
      libPkg = pkgs.writeTextDir "skills/lib-only/SKILL.md" "# lib-only\n";
      srcPkg = pkgs.writeTextDir "skills/alpha/SKILL.md" "# alpha\n";
      collPkg = pkgs.writeTextDir "skills/bundle/SKILL.md" "# bundle\n";

      librarySkills = {
        lib-only = libPkg;
        bundle = collPkg;
      };
      skillLayouts = {
        bundle = "collection";
      };

      enabledSources = {
        demo = {
          enable = true;
          package = srcPkg;
          skillNames = [
            "alpha"
            "beta"
          ];
        };
      };

      disabledSources = {
        demo = {
          enable = false;
          package = null;
          skillNames = [ ];
        };
      };

      collidingSources = {
        demo = {
          enable = true;
          package = srcPkg;
          skillNames = [ "lib-only" ];
        };
      };

      merged = mergeLib.mergeSkillCatalog librarySkills enabledSources;
      mergedDisabled = mergeLib.mergeSkillCatalog librarySkills disabledSources;
      dupTry = builtins.tryEval (mergeLib.mergeSkillCatalog librarySkills collidingSources);

      # Same collection filter the three adapters apply.
      plain =
        layouts: skills: lib.filterAttrs (name: _: (layouts.${name} or "skill") != "collection") skills;

      sortedEq = a: b: (lib.sort builtins.lessThan a) == (lib.sort builtins.lessThan b);

      assertions = [
        {
          name = "enabled-source-skills-present";
          ok = sortedEq (builtins.attrNames merged) [
            "alpha"
            "beta"
            "bundle"
            "lib-only"
          ];
        }
        {
          name = "disabled-source-omitted";
          ok = sortedEq (builtins.attrNames mergedDisabled) [
            "bundle"
            "lib-only"
          ];
        }
        {
          name = "duplicate-with-library-fails";
          ok = !dupTry.success;
        }
        {
          name = "collection-filter-unchanged";
          ok = sortedEq (builtins.attrNames (plain skillLayouts merged)) [
            "alpha"
            "beta"
            "lib-only"
          ];
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;
    in
    {
      checks.merge-skill-catalog =
        if failures != [ ] then
          throw ("merge-skill-catalog mismatches: " + lib.concatMapStringsSep ", " (a: a.name) failures)
        else
          pkgs.runCommand "merge-skill-catalog" { } ''
            set -euo pipefail
            test -f ${merged.alpha}/skills/alpha/SKILL.md
            test -f ${merged.lib-only}/skills/lib-only/SKILL.md
            echo "merge-skill-catalog OK" > "$out"
          '';
    };
}
