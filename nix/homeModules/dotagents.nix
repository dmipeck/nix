{ config, ... }@flakeArgs:
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

  # Agent command files (nix/dotagents/commands/*.nix), e.g. the scaffold
  # slash command built by dmipeck/agents (commands/scaffold.md);
  # passed through here so the home-manager module can hand them to each AI
  # tool's custom command set.
  commands = flakeArgs.config.dotagents.commands;
in
{

  # Home-manager config layer for the tool-agnostic "AI coding assistant"
  # core. Declares the per-user instance options (grafana / gitlab) and the
  # shared context; the MCP servers, skills and command files are defined in
  # the dmipeck/agents repo. This module overlays instance-specific values
  # (grafana URL/token file, gitlab URL) onto the shared server definitions.
  # Add an instance option here; add a server, skill or command over in
  # dmipeck/agents.
  flake.homeModules.dotagents =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      mcps = config.dotagents.mcps;
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
            serviceAccountTokenSopsKey = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Name of the sops-nix secret holding the Grafana service account
                token. Its decrypted path is exposed to the mcp-grafana server
                via GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE. Leave as null to omit the
                token (empty string) — e.g. for anonymous/unauthenticated access.
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
                and/or `dotagents.mcps.argocd.tokenSopsKey` to configure it.
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
            tokenSopsKey = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Name of the sops-nix secret holding the ArgoCD API token.
                argocd-mcp reads the token value from ARGOCD_API_TOKEN (no
                token-file env exists), so the server is wrapped in a small
                bash shim that reads the sops-decrypted file into that env var
                at startup — the token value itself never lands in the Nix
                store or this repo. Leave as null to inherit ARGOCD_API_TOKEN
                from the shell environment instead.
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
                "''${url}/api/v4/mcp"). Authenticates either interactively via
                OAuth 2.0 on first use, or with a personal access token sent as
                an Authorization: Bearer header when `tokenSopsKey` is set.
                Only read when `dotagents.mcps.gitlab.enable` is true.
              '';
            };
            tokenSopsKey = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Name of the sops-nix secret holding the GitLab personal access
                token. The PAT is sent to the remote MCP server as an
                Authorization: Bearer header, read from the sops-decrypted file
                at runtime (the header references the file via opencode's
                "{file:...}" substitution, so the token value never lands in the
                Nix store or this repo). Leave as null to fall back to
                interactive OAuth 2.0 instead.
              '';
            };
          };
          github = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to add the github MCP servers to the AI tool's config.
                Off by default since not every profile needs GitHub access; set
                to true and provide `dotagents.mcps.github.tokenSopsKey` to
                enable it. Enabling adds two servers: `github` (read-write,
                using `tokenSopsKey`) and `github-ro` (read-only, using
                `readOnlyTokenSopsKey` when set, else falling back to
                `tokenSopsKey`).
              '';
            };
            tokenSopsKey = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Name of the sops-nix secret holding the GitHub Personal Access
                Token. github-mcp-server reads the token value from
                GITHUB_PERSONAL_ACCESS_TOKEN (no token-file env exists), so the
                server is wrapped in a small bash shim that reads the
                sops-decrypted file into that env var at startup — the token
                value itself never lands in the Nix store or this repo.

                The PAT needs only the scopes for the tools the server
                registers (create a PR, push changes, read comments and
                reviews); it must NOT get admin/delete powers. A classic PAT:
                `repo` (Contents read+write, Pull requests read+write, Issues
                read+write, Metadata read), plus `read:org` only if the
                context tools get_teams / get_team_members should work. A
                fine-grained PAT: Contents (Read and write), Pull requests
                (Read and write), Issues (Read and write), Metadata (Read).
                Never grant repository Administration, or anything beyond
                those — merge/delete/admin tools are excluded server-side, so
                a scoped-down PAT is the second layer of the same rule.
              '';
            };
            readOnlyTokenSopsKey = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Name of the sops secret holding the read-only GitHub PAT used
                by the `github-ro` server. When null, falls back to
                `tokenSopsKey` so a read-only server still exists but with the
                same PAT.
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

        commands = lib.mkOption {
          # Each command is a package (a single markdown command file) defined
          # in nix/dotagents/commands/*.nix and built by dmipeck/agents; passed
          # through to the adapters, which map it onto each tool's custom
          # command slot.
          type = lib.types.attrsOf lib.types.anything;
          description = "Agent command files (defined in nix/dotagents/commands/).";
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
              GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE =
                if mcps.grafana.serviceAccountTokenSopsKey != null then
                  config.sops.secrets.${mcps.grafana.serviceAccountTokenSopsKey}.path
                else
                  "";
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
              if mcps.argocd.tokenSopsKey != null then "${pkgs.bash}/bin/bash" else baseMcpServers.argocd.command;
            args =
              if mcps.argocd.tokenSopsKey != null then
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
              // lib.optionalAttrs (mcps.argocd.tokenSopsKey != null) {
                ARGOCD_API_TOKEN_FILE = config.sops.secrets.${mcps.argocd.tokenSopsKey}.path;
              };
          };
        }
        // lib.optionalAttrs mcps.gitlab.enable {
          gitlab = baseMcpServers.gitlab // {
            url = "${mcps.gitlab.url}/api/v4/mcp";
            # A read-only PAT (when configured) is sent as an
            # Authorization: Bearer header on every request. The header value
            # references the sops-decrypted secret file via opencode's
            # "{file:...}" substitution, so only the file path ever appears in
            # the Nix store / generated config, never the token.
            headers = lib.optionalAttrs (mcps.gitlab.tokenSopsKey != null) {
              Authorization = "Bearer {file:${config.sops.secrets.${mcps.gitlab.tokenSopsKey}.path}}";
            };
          };
        }
        // lib.optionalAttrs mcps.github.enable (
          let
            # The read-only server's PAT: its own read-only secret when
            # configured, else the read-write secret so the server still works.
            roSecret =
              if mcps.github.readOnlyTokenSopsKey != null then
                config.sops.secrets.${mcps.github.readOnlyTokenSopsKey}.path
              else
                config.sops.secrets.${mcps.github.tokenSopsKey}.path;
          in
          {
            github = baseMcpServers.github // {
              # github-mcp-server has no token-file env var, so wrap the binary
              # in a bash shim that reads the sops-decrypted PAT file into
              # GITHUB_PERSONAL_ACCESS_TOKEN at startup. Only the file path ever
              # appears in the Nix store / generated config, never the token.
              command = "${pkgs.bash}/bin/bash";
              args = [
                "-c"
                ''
                  set -e
                  # bash builtin read (no `cat` PATH dependency) of the
                  # sops-decrypted PAT, exported to the env var the server reads.
                  GITHUB_PERSONAL_ACCESS_TOKEN="$(<"$GITHUB_PERSONAL_ACCESS_TOKEN_FILE")" \
                    exec ${baseMcpServers.github.command} ${lib.concatStringsSep " " (map lib.escapeShellArg baseMcpServers.github.args)}
                ''
              ];
              env = baseMcpServers.github.env // {
                GITHUB_PERSONAL_ACCESS_TOKEN_FILE = config.sops.secrets.${mcps.github.tokenSopsKey}.path;
              };
            };

            # Read-only twin: same bash shim shape, but the PAT is read from
            # `roSecret` above (the read-only secret when one is configured).
            # github-ro registers no write tools server-side (see
            # nix/dotagents/mcps/github.nix), so the shim only ever feeds a
            # read-only credential to a read-only tool surface.
            "github-ro" = baseMcpServers."github-ro" // {
              command = "${pkgs.bash}/bin/bash";
              args = [
                "-c"
                ''
                  set -e
                  # bash builtin read (no `cat` PATH dependency) of the
                  # sops-decrypted read-only PAT, exported to the env var the
                  # server reads.
                  GITHUB_PERSONAL_ACCESS_TOKEN="$(<"$GITHUB_PERSONAL_ACCESS_TOKEN_FILE")" \
                    exec ${baseMcpServers."github-ro".command} ${lib.concatStringsSep " " (map lib.escapeShellArg baseMcpServers."github-ro".args)}
                ''
              ];
              env = baseMcpServers."github-ro".env // {
                GITHUB_PERSONAL_ACCESS_TOKEN_FILE = roSecret;
              };
            };
          }
        );

        # Agent command files (defined in nix/dotagents/commands/*.nix) passed
        # straight through to each AI tool's custom command set.
        commands = commands;
      };
    };
}
