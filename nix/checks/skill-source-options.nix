# Skill Source HM options seam — evalModules over _skill-sources.nix with
# fixture trees. Asserts skill keys, enable gate, sibling retention, and that
# contentSources stays a no-emit stub. Adapter catalog merge is out of scope.
{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      fixture = ../dotagents/fixtures/skill-pack;

      skillSourceOptions = import ../homeModules/_skill-sources.nix { inherit lib pkgs; };

      eval =
        module:
        (lib.evalModules {
          modules = [
            {
              options.dotagents = lib.mkOption {
                type = lib.types.submodule {
                  options = skillSourceOptions;
                };
                default = { };
              };
            }
            module
          ];
        }).config.dotagents;

      flat = eval {
        config.dotagents.skillSources.demo = {
          src = fixture;
          root = "flat";
          layout = "flat";
        };
      };

      recursive = eval {
        config.dotagents.skillSources.demo = {
          src = fixture;
          root = "recursive";
          layout = "recursive";
        };
      };

      disabled = eval {
        config.dotagents.skillSources.demo = {
          enable = false;
          src = fixture;
          root = "flat";
          layout = "flat";
        };
      };

      stub = eval {
        config.dotagents.contentSources = {
          # Keys may be set; stub must not invent emit side-effects.
          future = { };
        };
      };

      sortedEq = a: b: (lib.sort builtins.lessThan a) == (lib.sort builtins.lessThan b);

      assertions = [
        {
          name = "flat-skill-names";
          ok = sortedEq flat.skillSources.demo.skillNames [
            "alpha"
            "beta"
          ];
        }
        {
          name = "recursive-skill-names";
          ok = sortedEq recursive.skillSources.demo.skillNames [
            "alpha"
            "gamma"
          ];
        }
        {
          name = "recursive-ignores-non-skill-keys";
          ok =
            !(builtins.elem "shared" recursive.skillSources.demo.skillNames)
            && !(builtins.elem "docs" recursive.skillSources.demo.skillNames)
            && !(builtins.elem "nest" recursive.skillSources.demo.skillNames);
        }
        {
          name = "disabled-omits-package";
          ok = disabled.skillSources.demo.skillNames == [ ] && disabled.skillSources.demo.package == null;
        }
        {
          name = "content-sources-stub-passthrough";
          ok = stub.contentSources == { future = { }; };
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;

      packCheck = pkgs.runCommand "skill-source-options" { } ''
        set -euo pipefail
        test -f ${flat.skillSources.demo.package}/skills/alpha/SKILL.md
        test -f ${flat.skillSources.demo.package}/skills/beta/SKILL.md
        test -f ${recursive.skillSources.demo.package}/skills/gamma/SKILL.md
        test -f ${recursive.skillSources.demo.package}/skills/shared/helper.md
        test -f ${recursive.skillSources.demo.package}/skills/docs/README.md
        echo "skill-source-options OK" > "$out"
      '';
    in
    {
      checks.skill-source-options =
        if failures != [ ] then
          throw ("skill-source-options mismatches: " + lib.concatMapStringsSep ", " (a: a.name) failures)
        else
          packCheck;
    };
}
