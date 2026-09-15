# MCP Adapter Emit propagation — authored Cursor-shaped mcp.json → Cursor /
# OpenCode / Claude dialects must carry the same server set. Catches adapters
# that drop servers (e.g. Claude hand-rolled catalogs missing grafana /
# playwright) so every consumer gets MCP definitions from the Common Model.
{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      mcpLib = import ../dotagents/_mcp.nix { inherit lib; };
      adapterEmit = import ../dotagents/_emit.nix {
        inherit lib;
        frontmatterLib = import ../lib/_frontmatter.nix { inherit lib; };
      };

      fixture = ../dotagents/fixtures/mcp-propagation;
      authored = (builtins.fromJSON (builtins.readFile (fixture + "/mcp.json"))).mcpServers;

      # Instance overlay: keep the fixture set; disable nothing. Mimics the
      # post-Instance catalog adapters read from config.dotagents.mcpServers.
      catalog = mcpLib.applyInstanceOverlay { } authored;

      expectedNames = builtins.sort builtins.lessThan (builtins.attrNames catalog);

      cursorMcp = adapterEmit.emitCursorMcp { mcpServers = catalog; };
      openCodeMcp = adapterEmit.emitOpenCodeMcp catalog;
      claudeMcp = adapterEmit.emitClaudeMcp catalog;

      cursorNames = builtins.sort builtins.lessThan (builtins.attrNames cursorMcp.mcpServers);
      openCodeNames = builtins.sort builtins.lessThan (builtins.attrNames openCodeMcp);
      claudeNames = builtins.sort builtins.lessThan (builtins.attrNames claudeMcp);

      sameNames =
        cursorNames == expectedNames && openCodeNames == expectedNames && claudeNames == expectedNames;

      cursorStdioOk = (cursorMcp.mcpServers.nixos.type or null) == "stdio";
      openCodeLocalOk = (openCodeMcp.nixos.type or null) == "local";
      openCodeRemoteOk = (openCodeMcp.gitlab.type or null) == "remote";
      claudeStdioOk = (claudeMcp.nixos.type or null) == "stdio";
      claudeHttpOk = (claudeMcp.gitlab.type or null) == "http";

      # Grafana + playwright must survive Claude emit (regression for the old
      # hand-rolled catalog that omitted them).
      claudeHasGrafana = claudeMcp ? grafana && (claudeMcp.grafana.type or null) == "stdio";
      claudeHasPlaywright = claudeMcp ? playwright && (claudeMcp.playwright.type or null) == "stdio";

      # Cursor rewrite still applies; OpenCode keeps {file:} for plane.
      cursorRewrotePlane =
        !(lib.hasInfix "{file:" cursorMcp.mcpServers.plane.headers.Authorization or "");
      openCodeKeepsFileRef = lib.hasInfix "{file:" openCodeMcp.plane.headers.Authorization or "";
      # Claude must not leak Cursor header placeholders into wire shape.
      claudeNoHeaders = !(claudeMcp.plane ? headers);

      assertions = [
        {
          name = "same-server-names-all-adapters";
          ok = sameNames;
        }
        {
          name = "catalog-non-empty";
          ok = expectedNames != [ ];
        }
        {
          name = "cursor-stdio-shape";
          ok = cursorStdioOk;
        }
        {
          name = "opencode-local-remote-shape";
          ok = openCodeLocalOk && openCodeRemoteOk;
        }
        {
          name = "claude-stdio-http-shape";
          ok = claudeStdioOk && claudeHttpOk;
        }
        {
          name = "claude-includes-grafana";
          ok = claudeHasGrafana;
        }
        {
          name = "claude-includes-playwright";
          ok = claudeHasPlaywright;
        }
        {
          name = "cursor-rewrites-file-refs";
          ok = cursorRewrotePlane;
        }
        {
          name = "opencode-keeps-file-refs";
          ok = openCodeKeepsFileRef;
        }
        {
          name = "claude-omits-cursor-headers";
          ok = claudeNoHeaders;
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;
    in
    {
      checks.mcp-adapter-propagation =
        if failures != [ ] then
          throw ("mcp-adapter-propagation mismatches: " + lib.concatMapStringsSep ", " (a: a.name) failures)
        else
          pkgs.runCommand "mcp-adapter-propagation" { } ''
            echo "mcp-adapter-propagation: cursor/opencode/claude MCP defs OK (${lib.concatStringsSep "," expectedNames})"
            touch "$out"
          '';
    };
}
