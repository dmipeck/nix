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

      # YAML single-quoted scalar: descriptions contain `: ` (mapping
      # separator in plain scalars), so quote every value and double any
      # internal single quote (YAML single-quote escape).
      yamlQuote = s: "'${lib.replaceStrings [ "'" ] [ "''" ] s}'";

      # Render an opencode agent (dotagents/agents/<name>/agent.md) into Claude
      # Code's dialect: a `name`/`description`/`tools` allowlist frontmatter
      # over the shared system-prompt body (the opencode
      # `mode`/`permission`/`tools` block is dropped), plus optional extra
      # frontmatter lines (e.g. an inline `mcpServers:` block for agents that
      # connect a server only while they run).
      claudeAgent =
        name: description: tools: extra:
        let
          frontmatter = lib.concatStringsSep "\n" (
            [
              "---"
              "name: ${name}"
              "description: ${yamlQuote description}"
              "tools: ${yamlQuote tools}"
            ]
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
      # dialect with the github MCP server scoped inline. They reuse the
      # per-user instance config from config.dotagents.mcpServers.github
      # (dotagents.nix wraps the server so the PAT is read from a
      # sops-decrypted file at startup), so they only exist when the github
      # instance is enabled. The block is hand-built YAML (args/env as YAML
      # flow collections) because the args carry shell-quoted shim text that
      # must not be shell-interpolated; lib.generators.toYAML is just toJSON
      # in current nixpkgs and would mix JSON into the YAML frontmatter.
      githubServer = config.dotagents.mcpServers.github;
      githubMcpBlock = ''
        mcpServers:
          - github:
              type: stdio
              command: ${githubServer.command}
              args: ${builtins.toJSON githubServer.args}
              env: ${builtins.toJSON githubServer.env}
      '';

      # Hand-tuned description/tools for the agents whose opencode frontmatter
      # does not carry a Claude Code-compatible spec (mode/permission maps,
      # inline mcpServers). nix and the github pair override their frontmatter
      # with an inline mcpServers block; orchestrate/test/commit/explore-git/git
      # get hand-written descriptions and tool allowlists.
      agentSpecs = {
        nix = {
          description = "Runs home-manager and nixos-rebuild commands and answers Nix/NixOS option and package questions via the nixos MCP server. A reporter only — runs what it is told and reports results; never fixes anything.";
          tools = "Read, Grep, Glob, Bash";
          extraFrontmatter = ''
            mcpServers:
              - nixos:
                  type: stdio
                  command: ${pkgs.mcp-nixos}/bin/mcp-nixos
          '';
        };
        github = {
          description = "Full GitHub development assistant — reads repos, commits, branches and code; creates and updates pull requests, issues and discussions; triggers and inspects Actions runs and logs. Write-capable: performs the GitHub operations asked of it.";
          tools = "mcp__github__*";
          extraFrontmatter = githubMcpBlock;
        };
        "explore-github" = {
          description = "Answers questions about git repositories — commits, branches, tags, trees, file contents, and code search — using the github MCP server's git tools. Read-only: reports, never mutates.";
          tools = "mcp__github__get_me, mcp__github__get_commit, mcp__github__get_file_contents, mcp__github__get_repository_tree, mcp__github__get_tag, mcp__github__list_branches, mcp__github__list_commits, mcp__github__list_tags, mcp__github__search_code, mcp__github__search_commits";
          extraFrontmatter = githubMcpBlock;
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
          description = "Answers questions about the current git repository — commits, branches, tags, diffs, logs, and working-tree state — using local git commands. Read-only: reports what it finds, never mutates.";
          tools = "Bash";
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
        in
        claudeAgent name (spec.description or (agentDescription name)) (spec.tools or defaultTools) (
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
          # shared dotagents/agents/<name>/agent.md files (nix with the nixos
          # MCP server scoped inline, the orchestrate main-session agent, the
          # test/commit workers, and the explore-github/github agents with the
          # github server scoped inline; the github pair only when the github
          # instance is enabled). The home-manager/claude-code module writes
          # them to ~/.claude/agents/<name>.md.
          agents =
            (lib.removeAttrs allClaudeAgents githubAgentNames)
            // lib.optionalAttrs config.dotagents.mcps.github.enable (
              lib.genAttrs githubAgentNames (n: allClaudeAgents.${n})
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
            permissions.deny = [
              "Bash(awk:*)"
              "Bash(sed:*)"
              "Bash(kubectl:*)"
            ];
            # PR merges always prompt, even inside the github subagent. The
            # github server only connects inside that agent, so the pattern
            # never fires in the main session.
            permissions.ask = [
              "mcp__github__merge_pull_request"
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
