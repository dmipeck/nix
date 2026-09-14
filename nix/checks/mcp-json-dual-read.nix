# MCP Server Definitions dual-read seam — authored mcp.json + Nix modules →
# Common Model mcpServers (Cursor-shaped), with Instance overlay. Asserts
# external behavior only: Cursor wire shape, secrets as ''${env:…}, no tool enums
# in authored content, Nix modules still contribute during migration.
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

      # Literal ${env:…} placeholders (avoid Nix antiquotation).
      envPh = name: "$" + "{env:${name}}";
      envPrefix = "$" + "{env:";

      authoredPath = ../../dotagents/mcp.json;
      authoredFile = builtins.fromJSON (builtins.readFile authoredPath);
      authored = authoredFile.mcpServers;

      # Stand-in Nix Server Definitions (legacy local/remote) — proves dual-read
      # still accepts mcps/*.nix shape during migration.
      nixServers = {
        nixos = {
          type = "local";
          command = "/nix/store/fake-mcp-nixos/bin/mcp-nixos";
          args = [ ];
          env = { };
          url = null;
          headers = { };
          oauth = null;
        };
        # Nix-only server (not in authored mcp.json) must still appear.
        "nix-only-probe" = {
          type = "remote";
          command = null;
          args = [ ];
          env = { };
          url = "https://example.test/nix-only";
          headers = { };
          oauth = null;
        };
      };

      dual = mcpLib.dualReadMcpServers {
        inherit authored;
        inherit nixServers;
      };

      # Instance overlay: URL + secret env placeholder (no literal secrets).
      overlaid = mcpLib.applyInstanceOverlay {
        gitlab = {
          enable = true;
          url = "https://gitlab.example/api/v4/mcp";
        };
        grafana = {
          enable = true;
          env = {
            GRAFANA_URL = "https://grafana.example";
            GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = envPh "GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE";
          };
        };
        plane = {
          enable = true;
          headers = {
            Authorization = "Bearer ${envPh "PLANE_API_TOKEN"}";
            "X-Workspace-slug" = "littlemonkey";
          };
        };
        # Disabled servers drop out of the Common Model view used for emit.
        "nix-only-probe" = {
          enable = false;
        };
      } dual;

      cursorMcp = adapterEmit.emitCursorMcp { mcpServers = overlaid; };

      # Authored file must not carry Nix tool allowlists (Cursor-illegal keys).
      authoredHasTools = builtins.any (s: s ? tools) (builtins.attrValues authored);

      # Every Authorization header in authored content uses ''${env:…} placeholders.
      authoredAuthOk =
        let
          headers = lib.concatMap (s: lib.attrValues (s.headers or { })) (builtins.attrValues authored);
        in
        builtins.all (h: !(lib.hasPrefix "Bearer " h) || lib.hasInfix envPrefix h) headers;

      assertions = [
        {
          name = "authored-mcp-json-exists";
          ok = authored ? nixos && authored ? gitlab && authored.nixos.type == "stdio";
        }
        {
          name = "dual-read-nix-overlays-command";
          ok = dual.nixos.command == nixServers.nixos.command;
        }
        {
          name = "dual-read-nix-only-server";
          ok = dual ? "nix-only-probe" && dual."nix-only-probe".url == "https://example.test/nix-only";
        }
        {
          name = "dual-read-keeps-authored-remote";
          ok = dual ? cloudflare && dual.cloudflare.url == authored.cloudflare.url;
        }
        {
          name = "instance-overlay-url";
          ok = overlaid.gitlab.url == "https://gitlab.example/api/v4/mcp";
        }
        {
          name = "instance-overlay-env-placeholder";
          ok =
            overlaid.grafana.env.GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE
            == envPh "GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE";
        }
        {
          name = "instance-overlay-headers-placeholder";
          ok = lib.hasInfix (envPh "PLANE_API_TOKEN") overlaid.plane.headers.Authorization;
        }
        {
          name = "instance-disable-drops-server";
          ok = !(overlaid ? "nix-only-probe");
        }
        {
          name = "no-tool-enums-in-authored";
          ok = !authoredHasTools;
        }
        {
          name = "authored-auth-uses-env-placeholders";
          ok = authoredAuthOk;
        }
        {
          name = "cursor-emit-stdio-shape";
          ok =
            cursorMcp.mcpServers.nixos.type or null == "stdio"
            && cursorMcp.mcpServers.gitlab ? url
            && !(cursorMcp.mcpServers.gitlab ? type && cursorMcp.mcpServers.gitlab.type == "remote");
        }
        {
          name = "cursor-emit-no-local-remote-type";
          ok =
            !(builtins.any (s: s.type or null == "local" || s.type or null == "remote") (
              builtins.attrValues cursorMcp.mcpServers
            ));
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;
    in
    {
      checks.mcp-json-dual-read =
        if failures != [ ] then
          throw ("mcp-json-dual-read mismatches: " + lib.concatMapStringsSep ", " (a: a.name) failures)
        else
          pkgs.runCommand "mcp-json-dual-read" { } ''
            echo "mcp-json-dual-read: authored mcp.json dual-read + Instance overlay OK"
            touch "$out"
          '';
    };
}
