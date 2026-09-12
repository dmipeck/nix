{
  config,
  lib,
  ...
}@flakeArgs:
let
  # Shared MCP server configs (neutral model + concrete servers) live in
  # nix/dotagents/ (option model in dotagents.nix, per-server configs in mcps/);
  # captured here from flake-parts state so the home-manager module can
  # overlay the per-user instance values.
  baseMcpServers = flakeArgs.config.dotagents.mcpServers;

  # Global agent rules (nix/dotagents/rules.nix) are owned by dmipeck/agents
  # (agents.md) and passed through here; the home-manager module uses them
  # as the default for the shared `context` written to each AI tool's global
  # rules file.
  rules = flakeArgs.config.dotagents.rules;

  sopsLib = import ../lib/_sops.nix { inherit lib; };
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

      grafanaTokenPath = sopsLib.pathOrNull config mcps.grafana.sops "serviceAccountToken";
      argocdTokenPath = sopsLib.pathOrNull config mcps.argocd.sops "token";
      githubClientSecretPath = sopsLib.pathOrNull config mcps.github.sops "clientSecret";
      cloudflareTokenPath = sopsLib.pathOrNull config mcps.cloudflare.sops "token";
      planeTokenPath = sopsLib.pathOrNull config mcps.plane.sops "token";

      # Cloudflare's managed MCP servers all authenticate with one Cloudflare
      # API token sent as an Authorization: Bearer header. The header value
      # references the sops-decrypted secret file via opencode's "{file:...}"
      # substitution, so only the file path ever appears in the Nix store /
      # generated config, never the token.
      cloudflareHeaders = lib.optionalAttrs (cloudflareTokenPath != null) {
        Authorization = "Bearer {file:${cloudflareTokenPath}}";
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
        # Shared global context written to each AI tool's global rules file —
        # ~/.config/opencode/AGENTS.md for opencode, ~/.claude/CLAUDE.md for
        # Claude Code. Defaults to the dmipeck/agents `dotagents.rules` content
        # (agents.md, instructing the agent to load the git-workflow and
        # caveman skills), passed through via nix/dotagents/rules.nix; overridable
        # per profile.
        context = lib.mkOption {
          type = lib.types.lines;
          description = ''
            Global agent instructions, applied across every session of each AI
            tool. Defaults to the dmipeck/agents global rules (loads the
            git-workflow and caveman skills); override for per-profile
            instructions.
          '';
        };

        mcps = {
          grafana = {
            url = lib.mkOption {
              type = lib.types.str;
              description = "Grafana instance URL passed as GRAFANA_URL to the mcp-grafana MCP server.";
            };
            sops = lib.mkOption {
              type = sopsLib.mkType;
              default = { };
              description = ''
                Sops-backed secrets for mcp-grafana. Gate with
                `dotagents.mcps.grafana.sops.enable`, then set
                `secrets.serviceAccountToken.key` (exposed as
                GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE). Leave disabled for
                anonymous/unauthenticated access.
              '';
            };
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
                The server is the self-hosted remote Plane MCP endpoint
                (https://mcp.plane.littlemonkey.co.nz). Off by default since
                not every profile has a Plane instance; set to true and
                provide `sops.secrets.token` to enable it.
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
        };

        mcpServers = lib.mkOption {
          # The neutral submodule type is defined once in nix/dotagents/dotagents.nix
          # (`dotagents.mcpServers`); this option just passes the final merged
          # attrs through to the adapters.
          type = lib.types.attrsOf lib.types.anything;
          description = "Neutral MCP server configs (defined in nix/dotagents/).";
        };
      };

      config.dotagents = {
        # Global agent instructions, shared by both tools (written to
        # ~/.config/opencode/AGENTS.md and ~/.claude/CLAUDE.md). The content is
        # owned once by dmipeck/agents (agents.md) and passed through via
        # `dotagents.rules` (nix/dotagents/rules.nix); declared as a default here so a
        # profile can still override it with its own instructions.
        context = lib.mkDefault rules;

        # Base server definitions (commands, args, tool lists) come from
        # nix/dotagents/ (mcps/*.nix); only the per-user instance values are
        # overlaid here.
        mcpServers = {
          nixos = baseMcpServers.nixos;
          playwright = baseMcpServers.playwright;
          kubernetes = baseMcpServers.kubernetes;
          grafana = baseMcpServers.grafana // {
            env = baseMcpServers.grafana.env // {
              GRAFANA_URL = mcps.grafana.url;
              # Points the server at the sops-decrypted secret *file* rather
              # than the token value itself, so the token never lands in the
              # Nix store or this repo. Left empty when unset, e.g. for
              # anonymous access.
              GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = if grafanaTokenPath != null then grafanaTokenPath else "";
            };
          };
        }
        // lib.optionalAttrs mcps.argocd.enable {
          argocd = baseMcpServers.argocd // {
            # argocd-mcp reads the API token from ARGOCD_API_TOKEN (no
            # token-file env exists), so wrap the binary in a bash shim that
            # reads the sops-decrypted file into that env var at startup —
            # the token value itself never lands in the Nix store or this repo.
            command =
              if argocdTokenPath != null then "${pkgs.bash}/bin/bash" else baseMcpServers.argocd.command;
            args =
              if argocdTokenPath != null then
                [
                  "-c"
                  ''
                    set -e
                    ARGOCD_API_TOKEN="$(<"$ARGOCD_API_TOKEN_FILE")" \
                      exec ${baseMcpServers.argocd.command} ${lib.concatStringsSep " " (map lib.escapeShellArg baseMcpServers.argocd.args)}
                  ''
                ]
              else
                baseMcpServers.argocd.args;
            env =
              baseMcpServers.argocd.env
              // lib.optionalAttrs (mcps.argocd.url != null) {
                ARGOCD_BASE_URL = mcps.argocd.url;
              }
              // lib.optionalAttrs (argocdTokenPath != null) {
                ARGOCD_API_TOKEN_FILE = argocdTokenPath;
              };
          };
        }
        // lib.optionalAttrs mcps.gitlab.enable {
          gitlab = baseMcpServers.gitlab // {
            url = "${mcps.gitlab.url}/api/v4/mcp";
          };
        }
        // lib.optionalAttrs mcps.github.enable {
          # The hosted remote server does not support dynamic client registration, so
          # when a pre-registered OAuth App is configured its credentials ride on the
          # server entry as an `oauth` block. The client secret is referenced via
          # opencode's "{file:...}" substitution pointing at the sops-decrypted file,
          # so only the file path ever appears in the Nix store / generated config.
          github =
            baseMcpServers.github
            // lib.optionalAttrs (mcps.github.oauth.clientId != null) {
              oauth = {
                clientId = mcps.github.oauth.clientId;
              }
              // lib.optionalAttrs (mcps.github.oauth.scope != null) {
                scope = mcps.github.oauth.scope;
              }
              // lib.optionalAttrs (githubClientSecretPath != null) {
                clientSecret = "{file:${githubClientSecretPath}}";
              };
            };
        }
        // lib.optionalAttrs mcps.cloudflare.enable {
          cloudflare = baseMcpServers.cloudflare // cloudflareHeaders;
        }
        // lib.optionalAttrs mcps.cloudflare.bindings.enable {
          "cloudflare-bindings" = baseMcpServers."cloudflare-bindings" // cloudflareHeaders;
        }
        // lib.optionalAttrs mcps.cloudflare.observability.enable {
          "cloudflare-observability" = baseMcpServers."cloudflare-observability" // cloudflareHeaders;
        }
        // lib.optionalAttrs mcps.plane.enable {
          plane = baseMcpServers.plane // {
            headers = planeHeaders;
          };
        }
        // lib.optionalAttrs mcps.firebase.enable {
          firebase = baseMcpServers.firebase;
        };
      };
    };
}
