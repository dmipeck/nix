# MCP Server Definitions emit seam — authored mcp.json is the single SoT;
# Instance overlay + package resolve → Cursor wire shape; {file:} → ${env:…}
# before Cursor emit. No dual-read of Nix Server Definitions. Tool enums stay
# out of authored content.
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
      filePh = path: "{file:${path}}";

      authoredPath = ../../dotagents/mcp.json;
      authoredFile = builtins.fromJSON (builtins.readFile authoredPath);
      authored = authoredFile.mcpServers;

      # resolveMcpPackages expects packages coercible via "${pkg}/bin/…".
      resolved = mcpLib.resolveMcpPackages {
        mcp-nixos = "/nix/store/fake-mcp-nixos";
        plane-mcp = "/nix/store/fake-plane-mcp";
      } authored;

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
          env = {
            PLANE_BASE_URL = "https://plane.example/api";
            PLANE_API_KEY_FILE = "/run/secrets/plane-token";
          };
        };
        cloudflare = {
          enable = true;
          headers = {
            Authorization = "Bearer ${filePh "/run/secrets/cloudflare-token"}";
          };
        };
        # Disabled servers drop out of the catalog used for emit.
        firebase = {
          enable = false;
        };
      } resolved;

      cursorMcp = adapterEmit.emitCursorMcp { mcpServers = overlaid; };
      fileRefs = adapterEmit.collectCursorMcpFileRefs { mcpServers = overlaid; };

      authoredHasTools = builtins.any (s: s ? tools) (builtins.attrValues authored);

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
          name = "no-dual-read-nix-server-defs";
          # Catalog comes from authored only; Nix-only probe keys must not appear.
          ok = !(overlaid ? "nix-only-probe") && overlaid ? nixos;
        }
        {
          name = "package-resolve-rewrites-command";
          ok =
            lib.hasPrefix "/nix/store/fake-mcp-nixos/bin/" resolved.nixos.command
            && lib.hasPrefix "/nix/store/fake-plane-mcp/bin/" resolved.plane.command;
        }
        {
          name = "instance-overlay-url";
          ok = overlaid.gitlab.url == "https://gitlab.example/api/v4/mcp";
        }
        {
          name = "instance-overlay-env-placeholder";
          ok =
            overlaid.grafana.env.GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE
            == envPh "GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE"
            && overlaid.plane.env.PLANE_BASE_URL == "https://plane.example/api";
        }
        {
          name = "instance-disable-drops-server";
          ok = !(overlaid ? firebase);
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
            && cursorMcp.mcpServers.plane.type or null == "stdio"
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
        {
          name = "cursor-emit-rewrites-file-refs";
          ok =
            lib.hasInfix (
              envPrefix + "DOTAGENTS_CURSOR_CLOUDFLARE_AUTHORIZATION"
            ) cursorMcp.mcpServers.cloudflare.headers.Authorization
            && !(lib.hasInfix "{file:" cursorMcp.mcpServers.cloudflare.headers.Authorization);
        }
        {
          name = "cursor-file-refs-collected";
          ok = builtins.any (r: r.name == "DOTAGENTS_CURSOR_CLOUDFLARE_AUTHORIZATION") fileRefs;
        }
      ];

      failures = builtins.filter (a: !a.ok) assertions;
    in
    {
      checks.mcp-json-dual-read =
        if failures != [ ] then
          throw ("mcp-json-emit mismatches: " + lib.concatMapStringsSep ", " (a: a.name) failures)
        else
          pkgs.runCommand "mcp-json-emit" { } ''
            echo "mcp-json-emit: mcp.json SoT + Instance overlay + Cursor {file:} rewrite OK"
            touch "$out"
          '';
    };
}
