# Adapter Emit golden seam — fixture Authoring Format tree → Cursor / OpenCode /
# Claude agent + rules emit + Cursor mcp.json. Asserts external behavior only
# (no parser AST / helper-name checks). Frontmatter Parser is covered transitively.
{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      frontmatterLib = import ../lib/_frontmatter.nix { inherit lib; };
      adapterEmit = import ../dotagents/_emit.nix {
        inherit lib frontmatterLib;
      };

      fixture = ../dotagents/fixtures/authoring-format;
      agent = frontmatterLib.importMarkdown (fixture + "/agents/github.md");
      rules = frontmatterLib.importMarkdown (fixture + "/rules/dotagents.mdc");
      mcp = builtins.fromJSON (builtins.readFile (fixture + "/mcp.json"));

      cursorAgent = adapterEmit.emitCursorAgent agent;
      opencodeAgent = adapterEmit.emitOpenCodeAgent agent {
        model = "opencode-go/minimax-m3";
        variant = "none";
      };
      claudeAgent = adapterEmit.emitClaudeAgent agent {
        model = "haiku";
        effort = "low";
        mcpServers = {
          github = {
            type = "stdio";
            command = "github-mcp";
            args = [ ];
          };
        };
      };
      cursorMcp = adapterEmit.emitCursorMcp mcp;
      cursorRules = adapterEmit.emitCursorRules rules;
      opencodeRules = adapterEmit.emitOpenCodeRules rules;
      claudeRules = adapterEmit.emitClaudeRules rules;

      expectedCursorAgent = builtins.readFile (fixture + "/expected/cursor/agents/github.md");
      expectedOpenCodeAgent = builtins.readFile (fixture + "/expected/opencode/agents/github.md");
      expectedClaudeAgent = builtins.readFile (fixture + "/expected/claude/agents/github.md");
      expectedCursorMcp = builtins.fromJSON (builtins.readFile (fixture + "/expected/cursor/mcp.json"));
      expectedCursorRules = builtins.readFile (fixture + "/expected/cursor/rules/dotagents.mdc");
      expectedOpenCodeRules = builtins.readFile (fixture + "/expected/opencode/AGENTS.md");
      expectedClaudeRules = builtins.readFile (fixture + "/expected/claude/CLAUDE.md");

      assertions = [
        {
          name = "cursor-agent";
          ok = cursorAgent == expectedCursorAgent;
        }
        {
          name = "opencode-agent";
          ok = opencodeAgent == expectedOpenCodeAgent;
        }
        {
          name = "claude-agent";
          ok = claudeAgent == expectedClaudeAgent;
        }
        {
          name = "cursor-mcp";
          ok = cursorMcp == expectedCursorMcp;
        }
        {
          name = "cursor-rules";
          ok = cursorRules == expectedCursorRules;
        }
        {
          name = "cursor-rules-always-apply";
          ok = (rules.frontmatter.alwaysApply or false) == true;
        }
        {
          name = "opencode-rules";
          ok = opencodeRules == expectedOpenCodeRules;
        }
        {
          name = "claude-rules";
          ok = claudeRules == expectedClaudeRules;
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;
    in
    {
      checks.adapter-emit-seam =
        if failures != [ ] then
          throw ("adapter-emit-seam mismatches: " + lib.concatMapStringsSep ", " (a: a.name) failures)
        else
          pkgs.runCommand "adapter-emit-seam" { } ''
            echo "adapter-emit-seam: agents + rules + cursor mcp.json OK"
            touch "$out"
          '';
    };
}
