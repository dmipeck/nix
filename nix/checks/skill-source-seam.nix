# Fixture Skill Source seam — minimal HM module graph:
# in-repo Authoring Format skills tree as Skill Source ∪ stub library catalog
# → adapter-shaped merged skill keys (same merge + collection filter as
# Cursor / OpenCode / Claude). No network, no GitLab.
#
# Asserts external outcomes only: which keys exist after merge, enable gate,
# duplicate abort, recursive nested SKILL.md discovery — not helper names or
# internal attr plumbing. Pack / options / pure-merge unit checks stay separate.
{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      fixture = ../dotagents/fixtures/skill-pack;
      skillSourceOptions = import ../homeModules/_skill-sources.nix { inherit lib pkgs; };
      mergeLib = import ../homeModules/_merge-skill-catalog.nix { inherit lib; };

      # Stand-in library packages (paths only — adapters need attr names + values).
      libOnly = pkgs.writeTextDir "skills/lib-only/SKILL.md" "# lib-only\n";
      bundle = pkgs.writeTextDir "skills/bundle/SKILL.md" "# bundle\n";
      alphaLib = pkgs.writeTextDir "skills/alpha/SKILL.md" "# library-alpha\n";

      defaultLibrary = {
        lib-only = libOnly;
        bundle = bundle;
      };
      defaultLayouts = {
        bundle = "collection";
      };

      # Minimal HM graph: real Skill Source options + injectable library catalog
      # + adapter merge exposing deployed skill keys (plain catalog attr names).
      eval =
        {
          module,
          librarySkills ? defaultLibrary,
          skillLayouts ? defaultLayouts,
        }:
        (lib.evalModules {
          modules = [
            {
              options.dotagents = lib.mkOption {
                type = lib.types.submodule {
                  options = skillSourceOptions // {
                    deployedSkills = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      readOnly = true;
                      description = "Plain skill keys after library ∪ Skill Sources merge.";
                    };
                    mergedCatalog = lib.mkOption {
                      type = lib.types.attrs;
                      readOnly = true;
                      description = "Merged catalog before collection filter (packages).";
                    };
                  };
                };
                default = { };
              };
            }
            (
              { config, ... }:
              let
                merged = mergeLib.mergeSkillCatalog librarySkills config.dotagents.skillSources;
                plain = lib.filterAttrs (name: _: (skillLayouts.${name} or "skill") != "collection") merged;
              in
              {
                config.dotagents = {
                  mergedCatalog = merged;
                  deployedSkills = lib.sort builtins.lessThan (builtins.attrNames plain);
                };
              }
            )
            module
          ];
        }).config.dotagents;

      flat = eval {
        module = {
          config.dotagents.skillSources.demo = {
            src = fixture;
            root = "flat";
            layout = "flat";
          };
        };
      };

      recursive = eval {
        module = {
          config.dotagents.skillSources.demo = {
            src = fixture;
            root = "recursive";
            layout = "recursive";
          };
        };
      };

      disabled = eval {
        module = {
          config.dotagents.skillSources.demo = {
            enable = false;
            src = fixture;
            root = "flat";
            layout = "flat";
          };
        };
      };

      # Library already owns "alpha"; flat fixture also packs alpha → eval aborts.
      # Force deployedSkills inside tryEval — merge is lazy on the attrset shell.
      dupTry = builtins.tryEval (
        (eval {
          librarySkills = defaultLibrary // {
            alpha = alphaLib;
          };
          module = {
            config.dotagents.skillSources.demo = {
              src = fixture;
              root = "flat";
              layout = "flat";
            };
          };
        }).deployedSkills
      );

      sortedEq = a: b: (lib.sort builtins.lessThan a) == (lib.sort builtins.lessThan b);

      assertions = [
        {
          name = "flat-merge-deploys-source-and-library";
          ok = sortedEq flat.deployedSkills [
            "alpha"
            "beta"
            "lib-only"
          ];
        }
        {
          name = "flat-collection-key-not-deployed";
          ok = !(builtins.elem "bundle" flat.deployedSkills);
        }
        {
          name = "enable-false-omits-source-skills";
          ok = sortedEq disabled.deployedSkills [ "lib-only" ];
        }
        {
          name = "duplicate-with-library-aborts";
          ok = !dupTry.success;
        }
        {
          name = "recursive-discovers-nested-skill-md";
          ok = sortedEq recursive.deployedSkills [
            "alpha"
            "gamma"
            "lib-only"
          ];
        }
        {
          name = "recursive-ignores-non-skill-dirs";
          ok =
            !(builtins.elem "shared" recursive.deployedSkills)
            && !(builtins.elem "docs" recursive.deployedSkills)
            && !(builtins.elem "nest" recursive.deployedSkills);
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;

      # Build-time: deployed Skill Source packages expose adapter layout paths.
      layoutCheck = pkgs.runCommand "skill-source-seam" { } ''
        set -euo pipefail
        test -f ${flat.mergedCatalog.alpha}/skills/alpha/SKILL.md
        test -f ${flat.mergedCatalog.beta}/skills/beta/SKILL.md
        test -f ${flat.mergedCatalog.lib-only}/skills/lib-only/SKILL.md
        test -f ${recursive.mergedCatalog.gamma}/skills/gamma/SKILL.md
        echo "skill-source-seam OK" > "$out"
      '';
    in
    {
      checks.skill-source-seam =
        if failures != [ ] then
          throw ("skill-source-seam mismatches: " + lib.concatMapStringsSep ", " (a: a.name) failures)
        else
          layoutCheck;
    };
}
