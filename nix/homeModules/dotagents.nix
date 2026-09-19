{
  config,
  sopsLib,
  mcpLib,
  ...
}@flakeArgs:
let
  # Authored Server Definitions (Cursor wire shape) from Common Model.
  authoredMcpServers = flakeArgs.config.dotagents.commonModel.mcpServers;
  # Nix-side tool enums (allowlists); not part of Cursor mcp.json emit.
  mcpToolEnums = flakeArgs.config.dotagents.mcpServers;
  # Stdio package bindings keyed by mcp.json command names.
  mcpPackages = flakeArgs.config.dotagents.mcpPackages;

  # Common Model rules (nix/dotagents/rules.nix): Cursor Authoring Format
  # `.mdc` under dotagents/rules/, parsed by the Frontmatter Parser. Bodies
  # concatenate into shared `context` for OpenCode/Claude; Cursor
  # passthrough uses each `rules.<stem>.path`.
  rules = flakeArgs.config.dotagents.rules;
in
{

  # Home-manager config layer for the tool-agnostic "AI coding assistant"
  # core. Declares the per-user instance options (grafana / gitlab) and the
  # shared context; the MCP servers and skills are defined in the dmipeck/nix
  # repo. This module overlays instance-specific values (grafana URL/token
  # file, gitlab URL) onto the shared server definitions.
  # Add an instance option here; add a server or skill over in dmipeck/nix.
  flake.homeModules.dotagents =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      mcps = config.dotagents.mcps;

      argocdTokenPath = sopsLib.pathOrNull config mcps.argocd.sops "token";
      githubClientSecretPath = sopsLib.pathOrNull config mcps.github.sops "clientSecret";
      cloudflareTokenPath = sopsLib.pathOrNull config mcps.cloudflare.sops "token";
      planeTokenPath = sopsLib.pathOrNull config mcps.plane.sops "token";
      giteaTokenPath = sopsLib.pathOrNull config mcps.gitea.sops "token";

      # Cloudflare's managed MCP servers all authenticate with one Cloudflare
      # API token sent as an Authorization: Bearer header. Multi-account user
      # tokens also need a cf-account-id header (from
      # `dotagents.mcps.cloudflare.accountId`). The Authorization value
      # references the sops-decrypted secret file via opencode's "{file:...}"
      # substitution, so only the file path ever appears in the Nix store /
      # generated config, never the token.
      cloudflareHeaders =
        lib.optionalAttrs (cloudflareTokenPath != null) {
          Authorization = "Bearer {file:${cloudflareTokenPath}}";
        }
        // lib.optionalAttrs (mcps.cloudflare.accountId != null) {
          "cf-account-id" = mcps.cloudflare.accountId;
        };

      # The self-hosted Plane MCP server authenticates with a Plane API PAT
      # sent as an Authorization: Bearer header, plus a required
      # X-Workspace-slug header. The token header value references the
      # sops-decrypted secret file via opencode's "{file:...}" substitution,
      # so only the file path ever appears in the Nix store / generated
      # config, never the token. The workspace slug comes from the per-user
      # `dotagents.mcps.plane.workspaceSlug` option (default "littlemonkey").
      planeHeaders = {
        "X-Workspace-slug" = mcps.plane.workspaceSlug;
      }
      // lib.optionalAttrs (planeTokenPath != null) {
        Authorization = "Bearer {file:${planeTokenPath}}";
      };
    in
    {
      options.dotagents = {
        # Shared global context written to OpenCode/Claude global rules files —
        # ~/.config/opencode/AGENTS.md / ~/.claude/CLAUDE.md. Defaults to the
        # Common Model rules body (Adapter Emit body-only); Cursor uses the
        # authored `.mdc` passthrough instead. Overridable per profile.
        context = lib.mkOption {
          type = lib.types.lines;
          description = ''
            Global agent instructions for OpenCode/Claude sessions. Defaults to
            the Common Model rules body from `dotagents/rules/*.mdc`; override
            for per-profile instructions.
          '';
        };

        mcps = {
          # Attr names become MCP server names (e.g. `grafana`,
          # `build13-grafana`). Each clones the authored `grafana` template
          # from mcp.json with per-instance URL / token env.
          grafana = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Whether to include this Grafana MCP server in the catalog.";
                  };
                  url = lib.mkOption {
                    type = lib.types.str;
                    description = "Grafana instance URL passed as GRAFANA_URL to mcp-grafana.";
                  };
                  sops = lib.mkOption {
                    type = sopsLib.mkType;
                    default = { };
                    description = ''
                      Sops-backed secrets for this Grafana MCP instance. Gate with
                      `sops.enable`, then set `secrets.serviceAccountToken.key`
                      (exposed as GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE). Leave
                      disabled for anonymous/unauthenticated access.
                    '';
                  };
                };
              }
            );
            default = { };
            description = ''
              Named Grafana MCP instances. Attr names are MCP server names in
              the catalog. Example:

                dotagents.mcps.grafana = {
                  grafana = {
                    url = "https://grafana.example";
                    sops = {
                      enable = true;
                      secrets.serviceAccountToken.key = "grafana_sa_token";
                    };
                  };
                  "build13-grafana" = {
                    url = "https://metrics.build13.example";
                    sops.enable = true;
                    sops.secrets.serviceAccountToken.key = "build13_grafana_sa_token";
                  };
                };
            '';
          };
          argocd = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to add the argocd MCP server to the AI tool's config.
                Off by default since not every profile has an ArgoCD instance to
                point it at; set to true and provide `dotagents.mcps.argocd.url`
                and/or `dotagents.mcps.argocd.sops` to configure it.
              '';
            };
            url = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                ArgoCD base URL passed as ARGOCD_BASE_URL to the argocd-mcp
                server. Leave as null to inherit ARGOCD_BASE_URL from the shell
                environment instead.
              '';
            };
            sops = lib.mkOption {
              type = sopsLib.mkType;
              default = { };
              description = ''
                Sops-backed secrets for argocd-mcp. Gate with
                `dotagents.mcps.argocd.sops.enable`, then set
                `secrets.token.key`. argocd-mcp reads ARGOCD_API_TOKEN (no
                token-file env), so the server is wrapped in a bash shim that
                reads the decrypted file at startup. Leave disabled to inherit
                ARGOCD_API_TOKEN from the shell.
              '';
            };
          };
          gitlab = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to add the gitlab MCP server to the AI tool's config.
                Off by default since not every profile has a GitLab instance to
                point it at; set to true and provide `dotagents.mcps.gitlab.url`
                to enable it.
              '';
            };
            url = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Base URL of the GitLab instance the gitlab MCP server connects
                to. The server itself is remote HTTP (served by GitLab at
                "''${url}/api/v4/mcp"). Authenticates via OAuth 2.0 on first use.
                Only read when `dotagents.mcps.gitlab.enable` is true.
              '';
            };
            oauth = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  clientId = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = ''
                      Client ID of a pre-registered non-confidential (public)
                      GitLab OAuth app for the GitLab-native MCP server
                      (<instance>/api/v4/mcp). Setting it selects the
                      pre-registered OAuth flow for Claude Code. Leave null to
                      use interactive OAuth instead.
                    '';
                  };
                  callbackPort = lib.mkOption {
                    type = lib.types.port;
                    default = 8765;
                    description = ''
                      Loopback port Claude Code uses for the OAuth callback.
                      Must match the redirect URI registered on the OAuth app:
                      http://localhost:<port>/callback
                    '';
                  };
                  scopes = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = ''
                      Space-separated OAuth scope(s) requested when
                      authorizing. GitLab's MCP server advertises "mcp".
                      Null requests whatever the app defaults to.
                    '';
                  };
                };
              };
              default = { };
              description = "Pre-registered GitLab OAuth app config for the GitLab-native remote MCP server (Claude Code).";
            };
          };
          github = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to add the github MCP server to the AI tool's config.
                The server is GitHub's hosted remote MCP endpoint
                (https://api.githubcopilot.com/mcp/), which does not support
                dynamic client registration. A pre-registered GitHub OAuth App
                can be configured via `oauth` (clientId, scope) and
                `sops.secrets.clientSecret`; without one it falls back to
                interactive OAuth on first use (opencode performs the OAuth
                flow client-side). Enabling
                adds the `github` server (read-write); the read-only
                `explore-github` subagent is limited to its read tools by its
                own tool allowlist.
              '';
            };
            callbackPort = lib.mkOption {
              type = lib.types.port;
              default = 8085;
              description = ''
                Loopback port published into the Local GitHub MCP Docker
                container for OAuth (`-p 127.0.0.1:<port>:<port>` and
                `GITHUB_OAUTH_CALLBACK_PORT`). Default 8085 matches the
                official image's baked-in app callback URL
                (http://localhost:8085/callback). Change only if that port
                is taken or you bring your own app registered on another port.
              '';
            };
            oauth = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  clientId = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = ''
                      Client ID of a pre-registered GitHub OAuth App. Register the app at
                      https://github.com/settings/developers with the callback URL opencode
                      uses: http://127.0.0.1:19876/mcp/oauth/callback. Required because
                      GitHub's hosted MCP server does not support dynamic client
                      registration. Leave null to fall back to interactive OAuth (which
                      fails against the hosted server).
                    '';
                  };
                  scope = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = ''
                      Space-separated OAuth scopes requested when authorizing. github-mcp-server
                      default grant set, e.g. "repo read:org read:user user:email read:packages
                      write:packages read:project project gist notifications". Null requests
                      whatever the app defaults to.
                    '';
                  };
                };
              };
              default = { };
              description = "Pre-registered GitHub OAuth App config for the hosted remote MCP server.";
            };
            sops = lib.mkOption {
              type = sopsLib.mkType;
              default = { };
              description = ''
                Sops-backed secrets for the github MCP OAuth app. Gate with
                `dotagents.mcps.github.sops.enable`, then set
                `secrets.clientSecret.key`. Referenced via opencode's
                "{file:...}" substitution so the value never lands in the Nix
                store.
              '';
            };
          };
          cloudflare = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to add the cloudflare (Code Mode) MCP server to the
                AI tool's config. Cloudflare's Code Mode server (served at
                https://mcp.cloudflare.com/mcp) gives full programmatic
                control over the Cloudflare API through three tools: docs,
                search and execute. Off by default since it needs a Cloudflare
                account; set to true and provide `sops.secrets.token` (or rely
                on interactive OAuth) to enable it.
              '';
            };
            bindings = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Whether to add the cloudflare-bindings MCP server (served at
                  https://bindings.mcp.cloudflare.com/mcp) to the AI tool's
                  config. Manages KV namespaces, Workers, R2 buckets, D1
                  databases and Hyperdrive configs through discrete per-resource
                  tools. Shares the Cloudflare API token configured via
                  `dotagents.mcps.cloudflare.sops.secrets.token`.
                '';
              };
            };
            observability = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Whether to add the cloudflare-observability MCP server (served
                  at https://observability.mcp.cloudflare.com/mcp) to the AI
                  tool's config. Answers worker logs, metrics and schema
                  questions; entirely read-only. Shares the Cloudflare API
                  token configured via
                  `dotagents.mcps.cloudflare.sops.secrets.token`.
                '';
              };
            };
            accountId = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Cloudflare account ID sent as the cf-account-id header to Cloudflare
                MCP servers. Used when the API token can access multiple accounts
                (user tokens); account-scoped tokens pin the account via auth and
                do not need this. Leave null to omit the header.
              '';
            };
            sops = lib.mkOption {
              type = sopsLib.mkType;
              default = { };
              description = ''
                Sops-backed secrets for Cloudflare MCP servers. Gate with
                `dotagents.mcps.cloudflare.sops.enable`, then set
                `secrets.token.key`. Sent as Authorization: Bearer via
                "{file:...}" substitution. Leave disabled to fall back to
                interactive OAuth 2.1.
              '';
            };
          };
          plane = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to add the plane MCP server to the AI tool's config.
                Off by default since not every profile has a Plane instance;
                set to true and provide `dotagents.mcps.plane.url` (and
                usually `sops.secrets.token`) to enable it.
              '';
            };
            url = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Base URL of the Plane MCP endpoint (e.g.
                https://mcp.plane.littlemonkey.co.nz). The remote server path
                "/http/api-key/mcp" is appended. Only read when
                `dotagents.mcps.plane.enable` is true. Leave null to keep the
                authored mcp.json URL.
              '';
            };
            workspaceSlug = lib.mkOption {
              type = lib.types.str;
              default = "littlemonkey";
              description = ''
                Plane workspace slug sent as the X-Workspace-slug header to
                the remote MCP server. The server requires this header to
                select the workspace. Defaults to "littlemonkey".
              '';
            };
            sops = lib.mkOption {
              type = sopsLib.mkType;
              default = { };
              description = ''
                Sops-backed secrets for the plane MCP server. Gate with
                `dotagents.mcps.plane.sops.enable`, then set
                `secrets.token.key`. Sent as Authorization: Bearer via
                "{file:...}" substitution. Leave disabled to connect without
                a token.
              '';
            };
          };
          firebase = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to add the firebase MCP server to the AI tool's
                config. The server is the official Firebase MCP shipped in
                firebase-tools (`firebase mcp`, local stdio). Off by default;
                set to true to enable it. Authenticates with the Firebase CLI
                credentials already present in the environment (`firebase
                login`) — no sops token.
              '';
            };
          };
          gitea = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to add the gitea MCP server to the AI tool's config.
                Off by default since not every profile has a Gitea instance to
                point it at; set to true and provide `dotagents.mcps.gitea.url`
                and/or `dotagents.mcps.gitea.sops` to configure it.
              '';
            };
            url = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Gitea instance URL passed as GITEA_HOST to gitea-mcp. Leave
                as null to inherit GITEA_HOST from the shell environment
                instead.
              '';
            };
            sops = lib.mkOption {
              type = sopsLib.mkType;
              default = { };
              description = ''
                Sops-backed secrets for gitea-mcp. Gate with
                `dotagents.mcps.gitea.sops.enable`, then set
                `secrets.token.key`. gitea-mcp reads GITEA_ACCESS_TOKEN (no
                token-file env), so the server is wrapped in a bash shim that
                reads the decrypted file at startup. Leave disabled to inherit
                GITEA_ACCESS_TOKEN from the shell.
              '';
            };
          };
        };

        mcpServers = lib.mkOption {
          # Final Instance-overlaid Cursor-shaped catalog for adapters.
          type = lib.types.attrsOf lib.types.anything;
          description = ''
            MCP catalog after Common Model (mcp.json) + package resolve +
            Instance overlay. Cursor wire shape (stdio / url / headers / auth /
            env); tool enums merged from Nix when present.
          '';
        };
      }
      // (import ./_skill-sources.nix { inherit lib pkgs; });

      config.dotagents = {
        # OpenCode/Claude Adapter Emit: bodies only from Common Model rules.
        # Declared as a default so a profile can still override instructions.
        context = lib.mkDefault (
          lib.concatMapStringsSep "\n\n" (name: lib.removeSuffix "\n" rules.${name}.body) (
            lib.sort (a: b: a < b) (builtins.attrNames rules)
          )
          + "\n"
        );

        # mcp.json SoT → resolve packages → Instance overlay → Cursor shape.
        # Always-on servers (nixos/playwright/kubernetes) keep enable
        # implicit; grafana expands from mcps.grafana attrs; gated servers
        # drop out when Instance enable is false.
        mcpServers =
          let
            resolved = mcpLib.resolveMcpPackages mcpPackages authoredMcpServers;

            # GitHub image tag from authored args (docker run … IMAGE stdio …).
            githubImage = lib.findFirst (lib.hasPrefix "ghcr.io/github/github-mcp-server:") null (
              resolved.github.args or [ ]
            );

            githubPort = toString mcps.github.callbackPort;

            # Clone authored `grafana` template once per named Instance.
            grafanaTemplate = resolved.grafana or null;
            enabledGrafana = lib.filterAttrs (_: inst: inst.enable) mcps.grafana;
            resolvedWithGrafana =
              assert grafanaTemplate != null || enabledGrafana == { };
              (builtins.removeAttrs resolved [ "grafana" ])
              // lib.mapAttrs (_: _: grafanaTemplate) enabledGrafana;

            grafanaInstances = lib.mapAttrs (
              _name: inst:
              let
                tokenPath = sopsLib.pathOrNull config inst.sops "serviceAccountToken";
              in
              {
                enable = true;
                env = {
                  GRAFANA_URL = inst.url;
                  GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = if tokenPath != null then tokenPath else "";
                };
              }
            ) enabledGrafana;

            instances = grafanaInstances // {
              # Gated servers: enable=false drops them from the catalog.
              argocd = {
                enable = mcps.argocd.enable;
              }
              // lib.optionalAttrs mcps.argocd.enable (
                let
                  baseCmd = resolved.argocd.command;
                  baseArgs = resolved.argocd.args or [ ];
                in
                {
                  # argocd-mcp reads ARGOCD_API_TOKEN (no token-file env), so
                  # wrap with bash that reads the sops file at startup.
                  command = if argocdTokenPath != null then "${pkgs.bash}/bin/bash" else baseCmd;
                  args =
                    if argocdTokenPath != null then
                      [
                        "-c"
                        ''
                          set -e
                          ARGOCD_API_TOKEN="$(<"$ARGOCD_API_TOKEN_FILE")" \
                            exec ${baseCmd} ${lib.concatStringsSep " " (map lib.escapeShellArg baseArgs)}
                        ''
                      ]
                    else
                      baseArgs;
                  env =
                    (resolved.argocd.env or { })
                    // lib.optionalAttrs (mcps.argocd.url != null) {
                      ARGOCD_BASE_URL = mcps.argocd.url;
                    }
                    // lib.optionalAttrs (argocdTokenPath != null) {
                      ARGOCD_API_TOKEN_FILE = argocdTokenPath;
                    };
                }
              );
              gitlab = {
                enable = mcps.gitlab.enable;
              }
              // lib.optionalAttrs mcps.gitlab.enable {
                url = "${mcps.gitlab.url}/api/v4/mcp";
              };
              github = {
                enable = mcps.github.enable;
              }
              // lib.optionalAttrs mcps.github.enable (
                assert githubImage != null;
                {
                  args = [
                    "run"
                    "-i"
                    "--rm"
                    "-p"
                    "127.0.0.1:${githubPort}:${githubPort}"
                    "-e"
                    "GITHUB_OAUTH_CALLBACK_PORT"
                    githubImage
                    "stdio"
                    "--toolsets"
                    "all"
                  ];
                  env = {
                    GITHUB_OAUTH_CALLBACK_PORT = githubPort;
                  };
                }
                // lib.optionalAttrs (mcps.github.oauth.clientId != null) {
                  auth = {
                    CLIENT_ID = mcps.github.oauth.clientId;
                  }
                  // lib.optionalAttrs (githubClientSecretPath != null) {
                    CLIENT_SECRET = "{file:${githubClientSecretPath}}";
                  }
                  // lib.optionalAttrs (mcps.github.oauth.scope != null) {
                    scopes = lib.splitString " " mcps.github.oauth.scope;
                  };
                }
              );
              cloudflare = {
                enable = mcps.cloudflare.enable;
              }
              // lib.optionalAttrs (mcps.cloudflare.enable && cloudflareHeaders != { }) {
                headers = cloudflareHeaders;
              };
              "cloudflare-bindings" = {
                enable = mcps.cloudflare.bindings.enable;
              }
              // lib.optionalAttrs (mcps.cloudflare.bindings.enable && cloudflareHeaders != { }) {
                headers = cloudflareHeaders;
              };
              "cloudflare-observability" = {
                enable = mcps.cloudflare.observability.enable;
              }
              // lib.optionalAttrs (mcps.cloudflare.observability.enable && cloudflareHeaders != { }) {
                headers = cloudflareHeaders;
              };
              plane = {
                enable = mcps.plane.enable;
              }
              // lib.optionalAttrs mcps.plane.enable { headers = planeHeaders; }
              // lib.optionalAttrs (mcps.plane.enable && mcps.plane.url != null) {
                url = "${mcps.plane.url}/http/api-key/mcp";
              };
              firebase = {
                enable = mcps.firebase.enable;
              };
              gitea = {
                enable = mcps.gitea.enable;
              }
              // lib.optionalAttrs mcps.gitea.enable (
                let
                  baseCmd = resolved.gitea.command;
                  baseArgs = resolved.gitea.args or [ ];
                in
                {
                  # gitea-mcp reads GITEA_ACCESS_TOKEN (no token-file env), so
                  # wrap with bash that reads the sops file at startup.
                  command = if giteaTokenPath != null then "${pkgs.bash}/bin/bash" else baseCmd;
                  args =
                    if giteaTokenPath != null then
                      [
                        "-c"
                        ''
                          set -e
                          GITEA_ACCESS_TOKEN="$(<"$GITEA_ACCESS_TOKEN_FILE")" \
                            exec ${baseCmd} ${lib.concatStringsSep " " (map lib.escapeShellArg baseArgs)}
                        ''
                      ]
                    else
                      baseArgs;
                  env =
                    (resolved.gitea.env or { })
                    // lib.optionalAttrs (mcps.gitea.url != null) {
                      GITEA_HOST = mcps.gitea.url;
                    }
                    // lib.optionalAttrs (giteaTokenPath != null) {
                      GITEA_ACCESS_TOKEN_FILE = giteaTokenPath;
                    };
                }
              );
            };

            overlaid = mcpLib.applyInstanceOverlay instances resolvedWithGrafana;

            # Merge Nix tool enums onto Cursor-shaped definitions (adapters
            # that still read tools.*; Cursor emit strips non-wire keys).
            # Grafana instances share the authored `grafana` tool enum.
            grafanaTools = mcpToolEnums.grafana.tools or null;
            withTools = lib.mapAttrs (
              name: srv:
              let
                tools =
                  if mcpToolEnums ? ${name} then
                    mcpToolEnums.${name}.tools
                  else if (enabledGrafana ? ${name}) && grafanaTools != null then
                    grafanaTools
                  else
                    null;
              in
              srv // lib.optionalAttrs (tools != null) { inherit tools; }
            ) overlaid;
          in
          withTools;
      };
    };
}
