{ inputs, config, ... }@flakeArgs:
let
  # Shared MCP server configs (neutral model + concrete servers) live once in
  # the dmipeck/agents repo; captured here from flake-parts state so the
  # home-manager module can overlay the per-user instance values.
  baseMcpServers = flakeArgs.config.agents.mcpServers;
in
{
  # flake-parts level: import the dmipeck/agents flakeModule so this flake's
  # eval exposes its `agents` options (skills, mcps, commands, mcpServers).
  # The claude and opencode adapters read `config.agents.skills` from here;
  # the home-manager module below owns the per-user wiring (instance options,
  # global context) on top of the shared MCP server and skill definitions.
  imports = [
    inputs.agents.flakeModules.agents
  ];

  # Home-manager config layer for the tool-agnostic "AI coding assistant"
  # core. Declares the per-user instance options (grafana / gitlab) and the
  # global context; the MCP servers and skill/plugin packages are defined in
  # the dmipeck/agents repo. This module overlays instance-specific values
  # (grafana URL/token file, gitlab URL) onto the shared server definitions.
  # Add an instance option here; add a server or skill over in dmipeck/agents.
  flake.homeModules.agents =
    {
      lib,
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
        };

        mcpServers = lib.mkOption {
          # The neutral submodule type is defined once in the dmipeck/agents
          # repo (`agents.mcpServers`); this option just passes the final
          # merged attrs through to the adapters.
          type = lib.types.attrsOf lib.types.anything;
          description = "Neutral MCP server configs (defined in dmipeck/agents).";
        };
      };

      config.agents = {
        # Global agent instructions, shared by both tools (written to
        # ~/.config/opencode/AGENTS.md and ~/.claude/CLAUDE.md). The
        # git-workflow and caveman skills it references are installed from the
        # dmipeck/agents skill set, so the loads resolve.
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

        # Base server definitions (commands, args, tool lists) come from the
        # dmipeck/agents repo; only the per-user instance values are overlaid
        # here.
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
        // lib.optionalAttrs instance.gitlab.enable {
          gitlab = baseMcpServers.gitlab // {
            url = "${instance.gitlab.url}/api/v4/mcp";
          };
        };
      };
    };
}
