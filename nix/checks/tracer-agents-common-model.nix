# Tracer agents Common Model seam — real Authoring Format tracers
# (github + explore-github) discovered via Frontmatter Parser, then Adapter
# Emit for Cursor / OpenCode / Claude. Asserts external FM + bodies only.
# Dual path: a legacy directory agent (commit) must still resolve as a path.
{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      frontmatterLib = import ../lib/_frontmatter.nix { inherit lib; };
      adapterEmit = import ../dotagents/_emit.nix {
        inherit lib frontmatterLib;
      };
      commonModelLib = import ../dotagents/_common-model.nix {
        inherit lib frontmatterLib;
      };

      agentsDir = ../../dotagents/agents;
      commonAgents = commonModelLib.discoverAgents agentsDir;

      expectedDir = ../dotagents/fixtures/tracer-agents/expected;

      injectCursorModel =
        agent: model:
        agent
        // {
          frontmatter = agent.frontmatter // {
            inherit model;
          };
        };

      github = commonAgents.github;
      exploreGithub = commonAgents.explore-github;

      cursorGithub = adapterEmit.emitCursorAgent (injectCursorModel github "composer-2.5");
      cursorExplore = adapterEmit.emitCursorAgent (injectCursorModel exploreGithub "composer-2.5");

      opencodeGithub = adapterEmit.emitOpenCodeAgent github {
        model = "opencode-go/minimax-m3";
        variant = "none";
      };
      opencodeExplore = adapterEmit.emitOpenCodeAgent exploreGithub {
        model = "opencode-go/minimax-m3";
        variant = "none";
      };

      sampleMcp = {
        github = {
          type = "stdio";
          command = "github-mcp";
          args = [ ];
        };
      };

      claudeGithub = adapterEmit.emitClaudeAgent github {
        model = "haiku";
        effort = "low";
        mcpServers = sampleMcp;
      };
      claudeExplore = adapterEmit.emitClaudeAgent exploreGithub {
        model = "haiku";
        effort = "low";
        tools = "Bash, mcp__github__get_commit";
        mcpServers = sampleMcp;
      };

      # Legacy dual-path: directory agent still present as agent.md
      legacyCommit = agentsDir + "/commit/agent.md";

      assertions = [
        {
          name = "common-model-has-tracers";
          ok = (commonAgents ? github) && (commonAgents ? explore-github);
        }
        {
          name = "tracers-not-legacy-dirs";
          ok =
            !(builtins.pathExists (agentsDir + "/github/agent.md"))
            && !(builtins.pathExists (agentsDir + "/explore-github/agent.md"));
        }
        {
          name = "legacy-commit-path";
          ok = builtins.pathExists legacyCommit;
        }
        {
          name = "name-equals-stem-github";
          ok = github.frontmatter.name == "github";
        }
        {
          name = "name-equals-stem-explore-github";
          ok = exploreGithub.frontmatter.name == "explore-github";
        }
        {
          name = "cursor-github";
          ok = cursorGithub == builtins.readFile (expectedDir + "/cursor/agents/github.md");
        }
        {
          name = "cursor-explore-github";
          ok = cursorExplore == builtins.readFile (expectedDir + "/cursor/agents/explore-github.md");
        }
        {
          name = "opencode-github";
          ok = opencodeGithub == builtins.readFile (expectedDir + "/opencode/agents/github.md");
        }
        {
          name = "opencode-explore-github";
          ok = opencodeExplore == builtins.readFile (expectedDir + "/opencode/agents/explore-github.md");
        }
        {
          name = "claude-github";
          ok = claudeGithub == builtins.readFile (expectedDir + "/claude/agents/github.md");
        }
        {
          name = "claude-explore-github";
          ok = claudeExplore == builtins.readFile (expectedDir + "/claude/agents/explore-github.md");
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;
    in
    {
      checks.tracer-agents-common-model =
        if failures != [ ] then
          throw (
            "tracer-agents-common-model mismatches: " + lib.concatMapStringsSep ", " (a: a.name) failures
          )
        else
          pkgs.runCommand "tracer-agents-common-model" { } ''
            echo "tracer-agents-common-model: discovery + cursor/opencode/claude emit OK"
            touch "$out"
          '';
    };
}
