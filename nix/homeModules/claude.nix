{ config, ... }@flakeArgs:
let
  # Skill/plugin packages are owned by nix/dotagents/ (skills/*.nix); the
  # subagent definitions are auto-discovered from dotagents/agents/*/agent.md
  # (nix/dotagents/auto.nix). `config` here is flake-parts state
  # (auto-imported under nix/); captured once so the home-manager module below
  # can reference the packages.
  skills = flakeArgs.config.dotagents.skills;
  skillLayouts = flakeArgs.config.dotagents.skillLayouts;
  agents = flakeArgs.config.dotagents.agents;
  cheapSubagents = flakeArgs.config.dotagents.cheapSubagents;
in
{
  flake.homeModules.claude =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.claude-code;

      # Neutral MCP server configs + per-user instance options live in
      # homeModules/dotagents.nix; skill packages come from nix/dotagents/
      # (`skills`, captured above). This module is a thin adapter that maps
      # them onto Claude Code's config dialect. No MCP servers are registered
      # for the main session (see `mcpServers = {}` below), so their tool
      # descriptions never consume main-context; a subagent opts a server back
      # in with `mcpServers:` inline definitions in its agent file, which
      # connect only while that subagent runs.
      mcpServers = config.dotagents.mcpServers;

      # Render an opencode agent (dotagents/agents/<name>/agent.md) into Claude
      # Code's dialect: a `name`/`description`/`tools` allowlist frontmatter
      # over the shared system-prompt body (the opencode
      # `mode`/`permission`/`tools` block is dropped), plus an optional `model`
      # line (cheap worker subagents run on Claude's cheap model) and optional
      # extra frontmatter lines (e.g. an inline `mcpServers:` block for agents
      # that connect a server only while they run).
      claudeAgent =
        name: description: tools: model: extra:
        let
          frontmatter = lib.concatStringsSep "\n" (
            [
              "---"
              "name: ${name}"
              "description: ${description}"
              "tools: ${tools}"
            ]
            ++ lib.optional (model != "") "model: ${model}"
            ++ lib.optional (extra != "") extra
            ++ [ "---" ]
          );
        in
        pkgs.runCommand "dotagents-${name}-agent-claude" { } ''
              mkdir -p "$(dirname "$out")"
              {
                cat <<'EOF'
          ${frontmatter}

          EOF
                # Drop the shared file's opencode frontmatter block, keep the body.
                awk 'NR==1 && /^---$/{front=1; next} front && /^---$/{front=0; next} !front' ${agents.${name}}
              } > "$out"
        '';

      # The explore-github and github subagents, rendered for Claude Code's
      # dialect with the single github MCP server scoped inline. They reuse the
      # per-user instance config from config.dotagents.mcpServers (dotagents.nix
      # wraps the server so its PAT is read from a sops-decrypted file at
      # startup), so they only exist when the github instance is enabled.
      # explore-github restricts itself to read-only tools via its `tools`
      # allowlist below — the github server also registers write tools, but
      # none of them are allow-listed for explore-github. The block is
      # hand-built YAML (args/env as YAML flow collections) because the args
      # carry shell-quoted shim text that must not be shell-interpolated;
      # lib.generators.toYAML is just toJSON in current nixpkgs and would mix
      # JSON into the YAML frontmatter.
      githubServer = config.dotagents.mcpServers.github;
      githubMcpBlock = ''
        mcpServers:
          - github:
              type: stdio
              command: ${githubServer.command}
              args: ${builtins.toJSON githubServer.args}
              env: ${builtins.toJSON githubServer.env}
      '';

      # The gitlab MCP server, scoped inline for the gitlab and explore-gitlab
      # agents. It is the GitLab-native remote server (<instance>/api/v4/mcp),
      # not a local binary. Claude Code has no {file:...} substitution for
      # header values, so a tiny headersHelper script reads the sops-decrypted
      # PAT file at connection time and prints the Authorization header — only
      # the secret file path ever lands in the store / config.
      gitlabServer = config.dotagents.mcpServers.gitlab;
      gitlabHeadersHelper = pkgs.writeShellScriptBin "gitlab-mcp-headers" ''
        printf '{"Authorization": "Bearer %s"}' "$(<${
          config.sops.secrets.${config.dotagents.mcps.gitlab.tokenSopsKey}.path
        })"
      '';
      gitlabMcpBlock =
        let
          headersHelperLine = lib.optionalString (
            config.dotagents.mcps.gitlab.tokenSopsKey != null
          ) "        headersHelper: ${gitlabHeadersHelper}/bin/gitlab-mcp-headers\n";
        in
        ''
          mcpServers:
            - gitlab:
                type: http
                url: ${gitlabServer.url}
          ${headersHelperLine}
        '';
      argocdServer = config.dotagents.mcpServers.argocd;
      argocdMcpBlock = ''
        mcpServers:
          - argocd:
              type: stdio
              command: ${argocdServer.command}
              args: ${builtins.toJSON argocdServer.args}
              env: ${builtins.toJSON argocdServer.env}
      '';

      # The export-kubernetes subagent, rendered for Claude Code's dialect with
      # the kubernetes MCP server scoped inline. The server starts with
      # `--readonly` (nix/dotagents/mcps/kubernetes.nix), which disables the
      # apply-k8s-resource and k8s-pod-exec write tools, so the agent can only
      # inspect the cluster. The block is hand-built YAML like githubMcpBlock.
      kubernetesServer = config.dotagents.mcpServers.kubernetes;
      kubernetesMcpBlock = ''
        mcpServers:
          - kubernetes:
              type: stdio
              command: ${kubernetesServer.command}
              args: ${builtins.toJSON kubernetesServer.args}
      '';

      # Hand-tuned description/tools for the agents whose opencode frontmatter
      # does not carry a Claude Code-compatible spec (mode/permission maps,
      # inline mcpServers). explore-nix and the github pair override their
      # frontmatter with an inline mcpServers block;
      # orchestrate/test/commit/explore-git/git get hand-written descriptions
      # and tool allowlists.
      agentSpecs = {
        nix = {
          description = "'Applies and verifies nix configuration changes on this machine — the state-changing nix operations: nixos-rebuild switch/boot, home-manager switch/build, nix build, nix flake lock --update-input / nix flake update, nix profile and nix store operations, and nix-collect-garbage. Runs the exact write or build command given and reports the result. Read-only exploration and option lookups belong to the explore-nix subagent.'";
          tools = "Read, Grep, Glob, Bash";
        };
        "explore-nix" = {
          description = "'Explores and answers questions about nix and nixos configurations — this repo''s flake and module code, nixpkgs/home-manager options, and package versions — using read-only file access, read-only nix commands, and the nixos MCP option lookups. Read-only: reports what it finds, never mutates.'";
          tools = "Read, Grep, Glob, List, Bash";
          extraFrontmatter = ''
            mcpServers:
              - nixos:
                  type: stdio
                  command: ${pkgs.mcp-nixos}/bin/mcp-nixos
          '';
        };
        github = {
          # Single-quoted YAML scalar: the description contains `: ` which a
          # plain scalar would misparse as a mapping separator.
          description = "'Full GitHub development assistant — reads repos, commits, branches and code; creates and updates pull requests, issues and discussions; triggers and inspects Actions runs and logs. Write-capable: performs the GitHub operations asked of it.'";
          tools = "mcp__github__*";
          extraFrontmatter = githubMcpBlock;
        };
        "explore-github" = {
          description = "'Answers questions about git repositories — commits, branches, tags, trees, file contents, and code search — using the github MCP server''s read-only tools. Read-only: reports, never mutates.'";
          tools = "mcp__github__get_me, mcp__github__get_commit, mcp__github__get_file_contents, mcp__github__get_repository_tree, mcp__github__get_tag, mcp__github__list_branches, mcp__github__list_commits, mcp__github__list_tags, mcp__github__search_code, mcp__github__search_commits";
          extraFrontmatter = githubMcpBlock;
        };
        gitlab = {
          description = "'Write-capable GitLab development assistant — reads projects, issues, merge requests and pipelines with the gitlab MCP server, then creates issues, merge requests and notes, adds branches, manages pipelines and work items through its write tools. Write-capable: performs the GitLab operations asked of it.'";
          tools = "mcp__gitlab__*";
          extraFrontmatter = gitlabMcpBlock;
        };
        "explore-gitlab" = {
          description = "'Answers questions about GitLab — projects, issues, merge requests, repository files, pipelines and their jobs/logs, users, and work items — using the gitlab MCP server''s read-only tools. Read-only: reports, never mutates.'";
          tools = lib.concatStringsSep ", " (map (t: "mcp__gitlab__${t}") gitlabServer.readOnlyTools);
          extraFrontmatter = gitlabMcpBlock;
        };
        "export-kubernetes" = {
          description = "'Answers questions about a Kubernetes cluster - contexts, nodes, namespaces, events, resources, and pod logs - using the kubernetes MCP server''s tools. Read-only: reports what it finds, never mutates.'";
          tools = "mcp__kubernetes__get-k8s-pod-logs, mcp__kubernetes__get-k8s-resource, mcp__kubernetes__list-k8s-contexts, mcp__kubernetes__list-k8s-events, mcp__kubernetes__list-k8s-namespaces, mcp__kubernetes__list-k8s-nodes, mcp__kubernetes__list-k8s-resources";
          extraFrontmatter = kubernetesMcpBlock;
        };
        "explore-argocd" = {
          # Single-quoted YAML scalar: the description contains `: ` which a
          # plain scalar would misparse as a mapping separator.
          description = "'Answers questions about ArgoCD — applications, appprojects, clusters, resource trees, managed resources, and resource events — using the argocd MCP server. Read-only: reports, never mutates.'";
          tools = "mcp__argocd__list_clusters, mcp__argocd__get_appproject, mcp__argocd__list_applications, mcp__argocd__get_application, mcp__argocd__get_application_resource_tree, mcp__argocd__get_application_managed_resources, mcp__argocd__get_application_workload_logs, mcp__argocd__get_resource_events, mcp__argocd__get_resource_actions";
          extraFrontmatter = argocdMcpBlock;
        };
        orchestrate = {
          description = "Plans multi-step work, delegates every unit to the right subagent, tracks progress, and assembles the results into one final report. Has no tools of its own for exploring or editing — all lookups, searches, test runs, nix commands, and file changes happen through subagents. The default Claude Code main agent, invoked for every session — even when the user just says \"figure this out\", \"get this done\", or starts claude without naming an agent.";
          tools = "Agent, AskUserQuestion, TodoWrite, Skill";
        };
        test = {
          description = "Runs the test suite for one testing ecosystem, reviews the output, and reports pass/fail results. Reports failures only; never takes corrective action.";
          tools = "Read, Grep, Glob, List, Bash, Skill";
        };
        commit = {
          description = "Reviews pending changes, decides commit boundaries, and writes conventional + caveman-compressed commit messages.";
          tools = "Read, Grep, Glob, List, Bash, Skill";
        };
        "explore-git" = {
          description = "Answers questions about the current git repository — commits, branches, tags, diffs, logs, and working-tree state — using local git commands and read-only file access. Read-only: reports what it finds, never mutates.";
          tools = "Read, Grep, Glob, List, Bash";
        };
        git = {
          description = "Full git assistant — reads repo state (commits, branches, tags, diffs, working tree) and performs git operations: stage, commit, push, pull, branch, checkout/switch, worktree, merge, rebase, stash, tag, remote. Write-capable: does the git task asked of it.";
          tools = "Read, Grep, Glob, List, Bash, Skill";
        };
      };

      # Agents without a hand-tuned spec fall back to a description extracted
      # from their agent.md frontmatter (empty if missing) and a sensible
      # default tool allowlist.
      defaultTools = "Read, Grep, Glob, List, Bash, Skill";
      agentDescription =
        name:
        let
          m = builtins.match ".*description:[ \t]*([^\n]*)[\s\S]*" (builtins.readFile agents.${name});
        in
        if m == null then "" else builtins.head m;
      renderAgent =
        name:
        let
          spec = agentSpecs.${name} or { };
          extra = spec.extraFrontmatter or "";
          # Cheap worker subagents (config.dotagents.cheapSubagents) get their
          # model pinned to Claude's cheap model; every other agent stays
          # byte-identical (no `model:` line in its frontmatter).
          model = if lib.elem name cheapSubagents then "haiku" else "";
        in
        claudeAgent name (spec.description or (agentDescription name)) (spec.tools or defaultTools) model (
          lib.optionalString (extra != "") (lib.trim extra)
        );

      # All agent definitions (dotagents/agents/<name>/agent.md), rendered for
      # Claude Code's dialect; the github pair is registered only when the
      # per-user github instance is enabled.
      allClaudeAgents = lib.mapAttrs (name: _: renderAgent name) agents;
      githubAgentNames = [
        "explore-github"
        "github"
      ];
      gitlabAgentNames = [
        "explore-gitlab"
        "gitlab"
      ];
      argocdAgentNames = [
        "explore-argocd"
      ];

      # claude-statusline isn't packaged as a Claude Code plugin (no
      # .claude-plugin manifest) — statusLine is a top-level settings.json
      # field that plugins have no mechanism to declare, so it's wired in
      # directly via programs.claude-code.settings.statusLine instead.
      claudeStatuslineSrc = pkgs.fetchFromGitHub {
        owner = "vfmatzkin";
        repo = "claude-statusline";
        rev = "b8d0eb02efa11d2a7519ab8faca7dc2028d55e49";
        hash = "sha256-4eonTcAL8MNBeOlrGX6svE55SQAXaVu/OjB3Z8YH7FQ=";
      };
      claudeStatusline =
        pkgs.runCommand "claude-statusline" { nativeBuildInputs = [ pkgs.makeWrapper ]; }
          ''
            mkdir -p $out/bin
            cp ${claudeStatuslineSrc}/statusline-command.sh $out/bin/claude-statusline
            chmod +x $out/bin/claude-statusline
            wrapProgram $out/bin/claude-statusline --prefix PATH : ${
              pkgs.lib.makeBinPath [
                pkgs.jq
                pkgs.bc
                pkgs.gnugrep
                pkgs.gawk
                pkgs.coreutils
                pkgs.git
              ]
            }
          '';
    in
    {
      config = {
        programs.claude-code = {
          enable = true;

          # Global context written to ~/.claude/CLAUDE.md, applied across every
          # Claude Code session. Content lives once in config.dotagents.context
          # (homeModules/dotagents.nix), shared with opencode.
          context = config.dotagents.context;
          # Every key of config.dotagents.skills (local auto-discovered skills +
          # every upstream skill package) becomes a Claude plugin named after the
          # skill, referenced by its $out/skills/<name> directory. The package
          # values coerce to paths, so no hand-curated name→package map lives
          # here — dropping a new skill into dotagents/skills/ needs no adapter
          # edit. Collection keys (layout "collection") are whole bundles
          # ($out/skills/ holds many constituent skills): they're rendered as
          # the package root (a whole plugin), not $out/skills/<name>.
          plugins = lib.mapAttrs' (
            name: pkg:
            lib.nameValuePair name (
              if (skillLayouts.${name} or "skill") == "collection" then pkg else "${pkg}/skills/${name}"
            )
          ) skills;
          commands = {
            set-budget = "${claudeStatuslineSrc}/.claude/commands/set-budget.md";
          }
          // config.dotagents.commands;
          # The subagents, re-rendered for Claude Code's agent dialect from the
          # shared dotagents/agents/<name>/agent.md files (explore-nix with
          # the nixos MCP server scoped inline, the orchestrate main-session
          # agent, the test/commit workers, the github and explore-github
          # agents both with the single github server scoped inline
          # (explore-github limited to read-only tools by its allowlist), and
          # the explore-argocd agent with the argocd server scoped inline; the
          # github pair only when the github instance is enabled, and
          # explore-argocd only when the argocd instance is enabled). The
          # home-manager/claude-code module writes
          # them to ~/.claude/agents/<name>.md.
          agents =
            (lib.removeAttrs allClaudeAgents (githubAgentNames ++ gitlabAgentNames ++ argocdAgentNames))
            // lib.optionalAttrs config.dotagents.mcps.github.enable (
              lib.genAttrs githubAgentNames (n: allClaudeAgents.${n})
            )
            // lib.optionalAttrs config.dotagents.mcps.gitlab.enable (
              lib.genAttrs gitlabAgentNames (n: allClaudeAgents.${n})
            )
            // lib.optionalAttrs config.dotagents.mcps.argocd.enable (
              lib.genAttrs argocdAgentNames (n: allClaudeAgents.${n})
            );
          # The upstream gopls-lsp/rust-analyzer-lsp marketplace plugins ship
          # with no .lsp.json manifest (anthropics/claude-plugins-official#379),
          # so their lspServers config in marketplace.json never actually
          # takes effect. Declaring the same servers here instead makes
          # home-manager synthesize a proper local plugin (.claude-plugin +
          # .lsp.json) that does work — pointed at the same gopls /
          # rust-analyzer packages installed by the golang and rust homeModules.
          lspServers = {
            gopls = {
              command = "${pkgs.gopls}/bin/gopls";
              extensionToLanguage = {
                ".go" = "go";
              };
            };
            rust-analyzer = {
              command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
              extensionToLanguage = {
                ".rs" = "rust";
              };
            };
            nixd = {
              command = "${pkgs.nixd}/bin/nixd";
              extensionToLanguage = {
                ".nix" = "nix";
              };
            };
            # Docker's own unified LSP (Dockerfiles, Compose, Bake). Claude
            # Code's extensionToLanguage only matches on file extension (no
            # bare-filename support), so an extension-less "Dockerfile" can't
            # be routed here — only "*.dockerfile"-suffixed files match.
            # Compose/Bake files are intentionally left unmapped too: they're
            # conventionally named "docker-compose.yaml"/"docker-bake.hcl",
            # and claiming the bare .yaml/.hcl extensions here would hijack
            # every YAML/HCL file in the repo, not just Docker's. Compose
            # files still get validated as YAML via yamlls + schemastore above.
            docker = {
              command = "${pkgs.docker-language-server}/bin/docker-language-server";
              args = [
                "start"
                "--stdio"
              ];
              extensionToLanguage = {
                ".dockerfile" = "dockerfile";
              };
            };
          };
          settings = {
            # The orchestrate is the default main-session agent, so every
            # session starts in the delegation-only orchestrate and routes
            # all grunt work through subagents.
            agent = "orchestrate";
            statusLine = {
              type = "command";
              command = "${claudeStatusline}/bin/claude-statusline";
              padding = 0;
            };

            # Claude Code's built-in `general-purpose` and `claude` fallback
            # subagents are denied so delegation always lands on a
            # purpose-built subagent; spawning `fork` or the write-capable
            # `github`/`gitlab` subagents (which connect their servers inline)
            # requires confirmation. The glab/glab-rw/gh CLIs stay installed
            # for humans but are denied to every agent.
            permissions.deny = [
              "Bash(awk:*)"
              "Bash(sed:*)"
              "Bash(kubectl:*)"
              "Bash(gh:*)"
              "Bash(glab:*)"
              "Bash(glab-rw:*)"
              "Agent(general-purpose)"
              "Agent(claude)"
            ];
            # PR merges always prompt, even inside the github subagent, and
            # spawning the write-capable github/gitlab subagents always
            # prompts, even inside orchestrate. The github server only
            # connects inside those agents, so the merge pattern never fires
            # in the main session.
            permissions.ask = [
              "mcp__github__merge_pull_request"
              "Agent(fork)"
              "Agent(github)"
              "Agent(gitlab)"
            ];
          };
          # No MCP servers in the main conversation. The shared server set
          # (config.dotagents.mcpServers, kept for reference above) is served to
          # subagents via inline `mcpServers:` frontmatter in their agent
          # files instead, so main-context stays free of MCP tool schemas.
          mcpServers = { };
        };

        # After every `home-manager switch`, replace the read-only
        # symlink with a real writable regular file seeded from the same
        # declared content, so Claude Code can write to it without crashing.
        home.file = lib.mkIf (cfg.settings != { } || cfg.marketplaces != { }) {
          "${cfg.configDir}/settings.json".force = true;
        };

        home.activation.claudeSettingsWritable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          settingsPath="${cfg.configDir}/settings.json"

          if [[ -L "$settingsPath" ]]; then
            storePath="$(readlink -f "$settingsPath")"
            verboseEcho "Replacing symlink $settingsPath with a writable copy of $storePath"
            run rm -f "$settingsPath"
            run install -m644 "$storePath" "$settingsPath"
          fi
        '';
      };
    };
}
