# Full local agent set on Common Model — flat Authoring Format discovery.
# Asserts name≡stem, orchestrate primary via Metadata, explore/export readonly,
# and no legacy agents/<id>/ directories remain (nix-private#60).
{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      frontmatterLib = import ../lib/_frontmatter.nix { inherit lib; };
      commonModelLib = import ../dotagents/_common-model.nix {
        inherit lib frontmatterLib;
      };

      agentsDir = ../../dotagents/agents;
      commonAgents = commonModelLib.discoverAgents agentsDir;

      expectedNames = [
        "cloudflare"
        "cloudflare-bindings"
        "commit"
        "edit"
        "explore-argocd"
        "explore-cloudflare"
        "explore-cloudflare-bindings"
        "explore-cloudflare-observability"
        "explore-firebase"
        "explore-git"
        "explore-github"
        "explore-gitlab"
        "explore-nix"
        "export-kubernetes"
        "firebase"
        "format"
        "git"
        "github"
        "gitlab"
        "lint"
        "nix"
        "orchestrate"
        "plane"
        "test"
      ];

      readonlyNames = builtins.filter (
        n: lib.hasPrefix "explore-" n || lib.hasPrefix "export-" n
      ) expectedNames;

      dirents = builtins.readDir agentsDir;
      legacyDirs = builtins.attrNames (lib.filterAttrs (_: v: v == "directory") dirents);

      missing = builtins.filter (n: !(commonAgents ? ${n})) expectedNames;
      extras = builtins.filter (n: !(builtins.elem n expectedNames)) (builtins.attrNames commonAgents);

      nameMismatches = builtins.filter (
        n: (commonAgents.${n}.frontmatter.name or null) != n
      ) expectedNames;

      readonlyMismatches = builtins.filter (
        n: !(commonAgents.${n}.frontmatter.readonly or false)
      ) readonlyNames;

      orchestrateMode = commonAgents.orchestrate.frontmatter.metadata.opencode.mode or null;

      assertions = [
        {
          name = "no-legacy-agent-dirs";
          ok = legacyDirs == [ ];
        }
        {
          name = "common-model-has-all-agents";
          ok = missing == [ ] && extras == [ ];
        }
        {
          name = "name-equals-stem";
          ok = nameMismatches == [ ];
        }
        {
          name = "explore-export-readonly";
          ok = readonlyMismatches == [ ];
        }
        {
          name = "orchestrate-primary";
          ok = orchestrateMode == "primary";
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;
    in
    {
      checks.agents-authoring-format =
        if failures != [ ] then
          throw (
            "agents-authoring-format mismatches: "
            + lib.concatMapStringsSep ", " (a: a.name) failures
            + lib.optionalString (missing != [ ]) (" missing=" + lib.concatStringsSep "," missing)
            + lib.optionalString (legacyDirs != [ ]) (" legacy=" + lib.concatStringsSep "," legacyDirs)
            + lib.optionalString (readonlyMismatches != [ ]) (
              " readonly=" + lib.concatStringsSep "," readonlyMismatches
            )
            + lib.optionalString (orchestrateMode != "primary") (" mode=" + toString orchestrateMode)
          )
        else
          pkgs.runCommand "agents-authoring-format" { } ''
            echo "agents-authoring-format: full local agent set on Common Model OK"
            touch "$out"
          '';
    };
}
