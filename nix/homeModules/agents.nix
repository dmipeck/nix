{ config, ... }@flakeArgs:
let
  # Shared MCP server configs (neutral model + concrete servers) live in
  # nix/agents/ (option model in agents.nix, per-server configs in mcps/);
  # captured here from flake-parts state so the home-manager module can
  # overlay the per-user instance values.
  baseMcpServers = flakeArgs.config.agents.mcpServers;
in
{

  # Home-manager config layer for the tool-agnostic "AI coding assistant"
  # core. Declares the per-user instance options (grafana / gitlab) and the
  # global context; the MCP servers and skill/plugin packages are defined in
  # the dmipeck/agents repo. This module overlays instance-specific values
  # (grafana URL/token file, gitlab URL) onto the shared server definitions.
  # Add an instance option here; add a server or skill over in dmipeck/agents.
  flake.homeModules.agents =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      instance = config.agents.instance;
    in
    {
      options.agents = {
        # Shared global context (instructing the agent to load the git-workflow
        # and caveman skills) written to each AI tool's global rules file —
        # ~/.config/opencode/AGENTS.md for opencode, ~/.claude/CLAUDE.md for
        # Claude Code. Declared once here so both adapters stay in sync.
        context = lib.mkOption {
          type = lib.types.lines;
          description = ''
            Global agent instructions, applied across every session of each AI
            tool. Loads the git-workflow skill before working on a git repo and
            the caveman skill for terse communication.
          '';
        };

        instance = {
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
                point it at; set to true and provide `agents.instance.gitlab.url`
                to enable it.
              '';
            };
            url = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Base URL of the GitLab instance the gitlab MCP server connects
                to. The server itself is remote HTTP (served by GitLab at
                "''${url}/api/v4/mcp") and authenticates interactively via OAuth
                2.0 on first use — no sops secret is needed here. Only read when
                `agents.instance.gitlab.enable` is true.
              '';
            };
          };
          github = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to add the github MCP server to the AI tool's config.
                Off by default since not every profile needs GitHub access; set
                to true and provide `agents.instance.github.tokenSopsKey` to
                enable it.
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
          };
        };

        mcpServers = lib.mkOption {
          # The neutral submodule type is defined once in nix/agents/agents.nix
          # (`agents.mcpServers`); this option just passes the final merged
          # attrs through to the adapters.
          type = lib.types.attrsOf lib.types.anything;
          description = "Neutral MCP server configs (defined in nix/agents/).";
        };
      };

      config.agents = {
        # Global agent instructions, shared by both tools (written to
        # ~/.config/opencode/AGENTS.md and ~/.claude/CLAUDE.md). The
        # git-workflow and caveman skills it references are installed from the
        # nix/agents/ skill set, so the loads resolve.
        context = ''
          # Global Agent Instructions

          ## Git repositories

          Before starting any work in a git repository, load the `git-workflow` skill:

          ```
          skill: git-workflow
          ```

          The skill contains the workflow and commit conventions that must be followed
          for every change taken from "about to start" to "merged". Load it before
          writing code, running commits, or opening pull requests.

          ## Communication style

          Load the `caveman` skill at the start of every session — always use
          ultra-compressed `caveman` communication mode unless the user explicitly
          requests otherwise:

          ```
          skill: caveman
          ```
        '';

        # Base server definitions (commands, args, tool lists) come from
        # nix/agents/ (mcps/*.nix); only the per-user instance values are
        # overlaid here.
        mcpServers = {
          nixos = baseMcpServers.nixos;
          playwright = baseMcpServers.playwright;
          kubernetes = baseMcpServers.kubernetes;
          grafana = baseMcpServers.grafana // {
            env = baseMcpServers.grafana.env // {
              GRAFANA_URL = instance.grafana.url;
              # Points the server at the sops-decrypted secret *file* rather
              # than the token value itself, so the token never lands in the
              # Nix store or this repo. Left empty when unset, e.g. for
              # anonymous access.
              GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE =
                if instance.grafana.serviceAccountTokenSopsKey != null then
                  config.sops.secrets.${instance.grafana.serviceAccountTokenSopsKey}.path
                else
                  "";
            };
          };
        }
        // lib.optionalAttrs (instance.argocd.url != null || instance.argocd.tokenSopsKey != null) {
          argocd = baseMcpServers.argocd // {
            # argocd-mcp reads the API token from ARGOCD_API_TOKEN (no
            # token-file env exists), so wrap the binary in a bash shim that
            # reads the sops-decrypted file into that env var at startup —
            # the token value itself never lands in the Nix store or this repo.
            command =
              if instance.argocd.tokenSopsKey != null then
                "${pkgs.bash}/bin/bash"
              else
                baseMcpServers.argocd.command;
            args =
              if instance.argocd.tokenSopsKey != null then
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
              // lib.optionalAttrs (instance.argocd.url != null) {
                ARGOCD_BASE_URL = instance.argocd.url;
              }
              // lib.optionalAttrs (instance.argocd.tokenSopsKey != null) {
                ARGOCD_API_TOKEN_FILE = config.sops.secrets.${instance.argocd.tokenSopsKey}.path;
              };
          };
        }
        // lib.optionalAttrs instance.gitlab.enable {
          gitlab = baseMcpServers.gitlab // {
            url = "${instance.gitlab.url}/api/v4/mcp";
          };
        }
        // lib.optionalAttrs instance.github.enable {
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
              GITHUB_PERSONAL_ACCESS_TOKEN_FILE = config.sops.secrets.${instance.github.tokenSopsKey}.path;
            };
          };
        };
      };
    };
}
