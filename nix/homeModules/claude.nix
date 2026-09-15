{
  config,
  sopsLib,
  adapterEmit,
  ...
}@flakeArgs:
let
  # Skill/plugin packages are owned by nix/dotagents/ (skills/*.nix); agents
  # come from the Common Model (flat Authoring Format via auto.nix). `config`
  # here is flake-parts state (auto-imported under nix/); captured once so the
  # home-manager module below can reference the packages. Enabled Skill Sources
  # merge in at HM eval (see skills below).
  librarySkills = flakeArgs.config.dotagents.skills;
  skillLayouts = flakeArgs.config.dotagents.skillLayouts;
  commonAgents = flakeArgs.config.dotagents.commonModel.agents;
  cheapSubagents = flakeArgs.config.dotagents.cheapSubagents;
  # Per-client default model + variation (config.dotagents.models); this
  # adapter reads the `claude` client.
  models = flakeArgs.config.dotagents.models;
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
      # Optional second Claude Code instance backed by the same dotagents-derived
      # content in its own config dir (options declared below).
      ds = config.dotagents.claudeDeepseek;
      cloudflareTokenPath = sopsLib.pathOrNull config config.dotagents.mcps.cloudflare.sops "token";
      planeTokenPath = sopsLib.pathOrNull config config.dotagents.mcps.plane.sops "token";
      deepseekApiKeyPath = sopsLib.pathOrNull config ds.sops "apiKey";

      # Common Model + Instance is Cursor-shaped (stdio / url). Claude Adapter
      # Emit converts to Claude wire (stdio / http) with headersHelper for
      # sops-backed tokens (Claude has no {file:} / ${env:} in MCP headers).
      mcpServers = config.dotagents.mcpServers;

      githubServer = mcpServers.github or null;
      githubMcpServers = lib.optionalAttrs (githubServer != null) {
        github = {
          type = "stdio";
          command = githubServer.command;
          args = githubServer.args or [ ];
        }
        // lib.optionalAttrs ((githubServer.env or { }) != { }) { env = githubServer.env; };
      };

      gitlabServer = mcpServers.gitlab or null;
      gitlabMcpServers =
        let
          oauth = config.dotagents.mcps.gitlab.oauth;
        in
        lib.optionalAttrs (gitlabServer != null) {
          gitlab = {
            type = "http";
            url = gitlabServer.url;
          }
          // lib.optionalAttrs (oauth.clientId != null) {
            oauth = {
              clientId = oauth.clientId;
              callbackPort = oauth.callbackPort;
            }
            // lib.optionalAttrs (oauth.scopes != null) { scopes = oauth.scopes; };
          };
        };

      cloudflareServer = mcpServers.cloudflare or null;
      cloudflareHeadersHelper =
        if cloudflareTokenPath != null then
          pkgs.writeShellScriptBin "cloudflare-mcp-headers" ''
            printf '{"Authorization": "Bearer %s"}' "$(<${cloudflareTokenPath})"
          ''
        else
          null;
      mkCloudflareMcpServers = name: url: {
        ${name} = {
          type = "http";
          inherit url;
        }
        // lib.optionalAttrs (cloudflareTokenPath != null) {
          headersHelper = "${cloudflareHeadersHelper}/bin/cloudflare-mcp-headers";
        };
      };
      cloudflareMcpServers = lib.optionalAttrs (cloudflareServer != null) (
        mkCloudflareMcpServers "cloudflare" cloudflareServer.url
      );
      cloudflareBindingsMcpServers = lib.optionalAttrs (mcpServers ? "cloudflare-bindings") (
        mkCloudflareMcpServers "cloudflare-bindings" mcpServers."cloudflare-bindings".url
      );
      cloudflareObservabilityMcpServers = lib.optionalAttrs (mcpServers ? "cloudflare-observability") (
        mkCloudflareMcpServers "cloudflare-observability" mcpServers."cloudflare-observability".url
      );

      planeServer = mcpServers.plane or null;
      planeHeadersHelper = pkgs.writeShellScriptBin "plane-mcp-headers" ''
        out='{"X-Workspace-slug": "${config.dotagents.mcps.plane.workspaceSlug}"'
        ${lib.optionalString (planeTokenPath != null) ''
          token="$(<"${planeTokenPath}")"
          out="$out, \"Authorization\": \"Bearer $token\""
        ''}
        out="$out}"
        printf '%s' "$out"
      '';
      planeMcpServers = lib.optionalAttrs (planeServer != null) {
        plane = {
          type = "http";
          url = planeServer.url;
          headersHelper = "${planeHeadersHelper}/bin/plane-mcp-headers";
        };
      };

      firebaseServer = mcpServers.firebase or null;
      firebaseMcpServers = lib.optionalAttrs (firebaseServer != null) {
        firebase = {
          type = "stdio";
          command = firebaseServer.command;
          args = firebaseServer.args or [ ];
        };
      };

      argocdServer = mcpServers.argocd or null;
      argocdMcpServers = lib.optionalAttrs (argocdServer != null) {
        argocd = {
          type = "stdio";
          command = argocdServer.command;
          args = argocdServer.args or [ ];
        }
        // lib.optionalAttrs ((argocdServer.env or { }) != { }) { env = argocdServer.env; };
      };

      kubernetesServer = mcpServers.kubernetes or null;
      kubernetesMcpServers = lib.optionalAttrs (kubernetesServer != null) {
        kubernetes = {
          type = "stdio";
          command = kubernetesServer.command;
          args = kubernetesServer.args or [ ];
        };
      };

      nixosServer = mcpServers.nixos or null;
      nixosMcpServers = lib.optionalAttrs (nixosServer != null) {
        nixos = {
          type = "stdio";
          command = nixosServer.command;
          args = nixosServer.args or [ ];
        };
      };

      # Catalog for Adapter Emit selection (gated servers only when Instance
      # enable left them in config.dotagents.mcpServers).
      claudeMcpCatalog =
        nixosMcpServers
        // kubernetesMcpServers
        // githubMcpServers
        // gitlabMcpServers
        // argocdMcpServers
        // cloudflareMcpServers
        // cloudflareBindingsMcpServers
        // cloudflareObservabilityMcpServers
        // planeMcpServers
        // firebaseMcpServers;

      # Common Model agents → Adapter Emit (shared fields + metadata.claude +
      # derived mcpServers/tools). No hand-tuned agentSpecs maps.
      renderCommonAgent =
        name: agent:
        let
          cheap = lib.elem name cheapSubagents;
          model = if cheap then models.claude.subagent.model else null;
          effort = if cheap then (models.claude.subagent.variation or null) else null;
          text = adapterEmit.emitClaudeAgent agent {
            inherit model effort;
            mcpCatalog = claudeMcpCatalog;
          };
        in
        pkgs.writeText "dotagents-${name}-agent-claude" text;

      # All agents from the Common Model (flat Authoring Format). MCP-backed
      # agents are gated below on their Instance enable flags.
      allClaudeAgents = lib.mapAttrs renderCommonAgent commonAgents;

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
      cloudflareAgentNames = [
        "explore-cloudflare"
        "cloudflare"
      ];
      cloudflareBindingsAgentNames = [
        "explore-cloudflare-bindings"
        "cloudflare-bindings"
      ];
      cloudflareObservabilityAgentNames = [
        "explore-cloudflare-observability"
      ];
      planeAgentNames = [
        "plane"
      ];
      firebaseAgentNames = [
        "explore-firebase"
        "firebase"
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

      # ---------------------------------------------------------------------
      # Content expressions for the primary Claude Code instance. Hoisted here
      # so the optional second "claude-deepseek" instance (below) renders the
      # exact same content into its own config dir. When `ds.enable` is false
      # the deepseek side is never evaluated and the primary output is
      # byte-identical to the pre-refactor module.
      # ---------------------------------------------------------------------
      claudeContext = config.dotagents.context;

      # Library catalog ∪ enabled Skill Sources (fail on duplicate ids).
      # Collection layout filter unchanged; Skill Source keys default to "skill".
      mergeSkillCatalog = (import ./_merge-skill-catalog.nix { inherit lib; }).mergeSkillCatalog;
      skills = mergeSkillCatalog librarySkills config.dotagents.skillSources;

      claudePlugins = lib.mapAttrs' (
        name: pkg:
        lib.nameValuePair name (
          if (skillLayouts.${name} or "skill") == "collection" then pkg else "${pkg}/skills/${name}"
        )
      ) skills;

      claudeCommands = {
        set-budget = "${claudeStatuslineSrc}/.claude/commands/set-budget.md";
      };

      claudeAgents =
        (lib.removeAttrs allClaudeAgents (
          githubAgentNames
          ++ gitlabAgentNames
          ++ argocdAgentNames
          ++ cloudflareAgentNames
          ++ cloudflareBindingsAgentNames
          ++ cloudflareObservabilityAgentNames
          ++ planeAgentNames
          ++ firebaseAgentNames
        ))
        // lib.optionalAttrs config.dotagents.mcps.github.enable (
          lib.genAttrs githubAgentNames (n: allClaudeAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.gitlab.enable (
          lib.genAttrs gitlabAgentNames (n: allClaudeAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.argocd.enable (
          lib.genAttrs argocdAgentNames (n: allClaudeAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.cloudflare.enable (
          lib.genAttrs cloudflareAgentNames (n: allClaudeAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.cloudflare.bindings.enable (
          lib.genAttrs cloudflareBindingsAgentNames (n: allClaudeAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.cloudflare.observability.enable (
          lib.genAttrs cloudflareObservabilityAgentNames (n: allClaudeAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.plane.enable (
          lib.genAttrs planeAgentNames (n: allClaudeAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.firebase.enable (
          lib.genAttrs firebaseAgentNames (n: allClaudeAgents.${n})
        );

      claudeLspServers = {
        # The upstream gopls-lsp/rust-analyzer-lsp marketplace plugins ship
        # with no .lsp.json manifest (anthropics/claude-plugins-official#379),
        # so their lspServers config in marketplace.json never actually takes
        # effect. Declaring the same servers here instead makes home-manager
        # synthesize a proper local plugin (.claude-plugin + .lsp.json) that
        # does work — pointed at the same gopls / rust-analyzer packages
        # installed by the golang and rust homeModules.
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
        # Docker's own unified LSP (Dockerfiles, Compose, Bake). Claude Code's
        # extensionToLanguage only matches on file extension (no bare-filename
        # support), so an extension-less "Dockerfile" can't be routed here —
        # only "*.dockerfile"-suffixed files match. Compose/Bake files are
        # intentionally left unmapped too: they're conventionally named
        # "docker-compose.yaml"/"docker-bake.hcl", and claiming the bare
        # .yaml/.hcl extensions here would hijack every YAML/HCL file in the
        # repo, not just Docker's. Compose files still get validated as YAML
        # via yamlls + schemastore above.
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

      claudeSettings = {
        # Default primary model + effort level (the variation), driven by
        # config.dotagents.models.claude.primary. The effortLevel field maps
        # the variation (low/medium/high/max) onto Claude Code's thinking
        # depth; a null variation omits the field.
        model = models.claude.primary.model;
        # The orchestrate is the default main-session agent, so every session
        # starts in the delegation-only orchestrate and routes all grunt work
        # through subagents.
        agent = "orchestrate";
        disableBundledSkills = true;
        disableWorkflows = true;
        disableRemoteControl = true;
        disableClaudeAiConnectors = true;
        disableArtifact = true;
        statusLine = {
          type = "command";
          command = "${claudeStatusline}/bin/claude-statusline";
          padding = 0;
        };

        # Claude Code's built-in `claude` fallback subagent is denied so
        # delegation lands on a purpose-built subagent; the generic
        # `general-purpose` subagent stays available as a last resort and
        # spawning it prompts (permissions.ask below), matching opencode's
        # `general` contract. Spawning `fork` or the write-capable
        # `github`/`gitlab` subagents (which connect their servers inline) also
        # requires confirmation. The gh/glab CLIs stay installed for human
        # shell use but are denied only on the orchestrate main-session agent
        # (its frontmatter above), not in the top-level permissions.deny:
        # delegation of gh/glab work routes through the
        # github/explore-github and gitlab/explore-gitlab subagents, which
        # allow the CLIs explicitly as a fallback when their MCP servers are
        # unavailable, and every other Bash-capable agent keeps them usable.
        # sops stays denied at the top level because agents have no need to
        # decrypt secrets; sops-nix already hands them the decrypted file
        # paths, so a top-level deny is the simplest gate.
        permissions.deny = [
          "Bash(awk:*)"
          "Bash(sed:*)"
          "Bash(kubectl:*)"
          "Bash(sops:*)"
          "Agent(claude)"
          "DesignSync"
          "NotebookEdit"
          "PushNotification"
          "RemoteTrigger"
          "ReportFindings"
          "ScheduleWakeup"
          "CronCreate"
          "CronDelete"
          "CronList"
        ];
        # PR merges always prompt, even inside the github subagent, and
        # spawning the write-capable github/gitlab subagents always prompts,
        # even inside orchestrate. The github server only connects inside those
        # agents, so the merge pattern never fires in the main session.
        permissions.ask = [
          "mcp__github__merge_pull_request"
          "Agent(fork)"
          "Agent(github)"
          "Agent(gitlab)"
          "Agent(general-purpose)"
          "Agent(cloudflare)"
          "Agent(cloudflare-bindings)"
          "Agent(plane)"
          "Agent(firebase)"
        ];
        # Read-only cross-tool config access: agents may read the tool config
        # content dirs (claude skills/agents/commands, opencode config,
        # dotagents-style ~/.opencode and ~/.agents trees) but only via
        # Read(...) rules — no Edit rules, so the grant stays read-only.
        # ~/.claude root is excluded (credentials + session history live
        # there). settings.json is the single file shared by both instances, so
        # when the deepseek instance is enabled its agents/commands/skills dirs
        # get the same read grant (inert for the primary `claude`).
        permissions.allow = [
          "Read(~/.agents/**)"
          "Read(~/.claude/agents/**)"
          "Read(~/.claude/commands/**)"
          "Read(~/.claude/skills/**)"
          "Read(~/.config/opencode/**)"
          "Read(~/.opencode/**)"
        ]
        ++ lib.optionals ds.enable [
          "Read(${ds.configDir}/agents/**)"
          "Read(${ds.configDir}/commands/**)"
          "Read(${ds.configDir}/skills/**)"
        ];
      }
      // lib.optionalAttrs (models.claude.primary.variation != null) {
        # The primary effort level (the variation) only when set.
        effortLevel = models.claude.primary.variation;
      };

      # ---------------------------------------------------------------------
      # Deepseek second instance: replicate home-manager's plugin wrapping so
      # the deepseek config dir holds the same skill plugin content as the
      # primary dir.
      # ---------------------------------------------------------------------
      jsonFormat = pkgs.formats.json { };

      # home-manager's programs.claude-code module wraps each `plugins.<name>`
      # source into a plugin dir it then links to `<configDir>/skills/<name>`.
      # Replicate that wrapping (home-manager modules/programs/claude-code/
      # lib.nix `mkPluginEntry`) here: top-level entries are symlinked into
      # $out (each component dir stays a single symlink to the original —
      # Claude Code's readdir accepts only regular files, so recursive linking
      # would drop every agent/command), and a plugin.json manifest is
      # synthesized when the source lacks one.
      mkPluginEntryDeepseek =
        name: plugin:
        pkgs.runCommand "claude-code-${name}" { } ''
          mkdir -p "$out"

          shopt -s dotglob nullglob
          for entry in "${plugin}"/*; do
            ln -s "$entry" "$out/$(basename "$entry")"
          done

          if [[ ! -e $out/.claude-plugin/plugin.json ]]; then
            # Replace the linked manifest directory with a real one so the
            # generated manifest can sit beside any existing contents.
            rm -f "$out/.claude-plugin"
            mkdir -p "$out/.claude-plugin"
            for entry in "${plugin}"/.claude-plugin/*; do
              ln -s "$entry" "$out/.claude-plugin/$(basename "$entry")"
            done
            install -m644 ${
              jsonFormat.generate "claude-code-${name}.json" { inherit name; }
            } "$out/.claude-plugin/plugin.json"
          fi
        '';

      # home-manager also synthesizes a "claude-code-home-manager" plugin from
      # cfg.lspServers (.claude-plugin/plugin.json + .lsp.json; a .mcp.json is
      # only added when mcpServers are set — the primary always has none).
      deepseekHmPlugin = pkgs.runCommand "claude-code-deepseek-hm-plugin" { } (
        ''
          install -Dm644 ${
            jsonFormat.generate "claude-code-plugin.json" { name = "claude-code-home-manager"; }
          } $out/.claude-plugin/plugin.json
        ''
        + lib.optionalString (claudeLspServers != { }) ''
          install -Dm644 ${jsonFormat.generate "claude-code-lsp.json" claudeLspServers} $out/.lsp.json
        ''
      );

      # modelPicker JSON passed via `claude --settings` so the DeepSeek models
      # show up as the instance's model options.
      deepseekModelPickerJson = builtins.toJSON {
        modelPicker = {
          options = map (m: { model = m; }) ds.modelPickerModels;
          replaceBuiltInOptions = true;
        };
      };

      # Launcher: a thin wrapper that points Claude Code at the deepseek config
      # dir + DeepSeek endpoint, then execs the same claude binary. Settings are
      # shared (the deepseek dir's settings.json is a symlink to the primary's
      # writable file), so only the model picker override is passed inline.
      deepseekLauncher = pkgs.writeShellScriptBin "claude-deepseek" ''
        export CLAUDE_CONFIG_DIR="${ds.configDir}"
        export ANTHROPIC_BASE_URL="${ds.baseUrl}"
        ${lib.optionalString (deepseekApiKeyPath != null) ''
          export ANTHROPIC_AUTH_TOKEN="$(cat ${deepseekApiKeyPath})"
        ''}
        export ANTHROPIC_MODEL="${ds.model}"
        export ANTHROPIC_DEFAULT_MODEL="${ds.model}"
        export CLAUDE_CODE_MAX_CONTEXT_TOKENS="${ds.maxContextTokens}"
        exec ${config.programs.claude-code.package}/bin/claude --settings '${deepseekModelPickerJson}' "$@"
      '';

      # home.file entries materializing the deepseek config dir. The CLAUDE.md,
      # agents, commands and skills are the very same content the primary
      # instance links, only under `ds.configDir`; settings.json is a symlink to
      # the primary's real writable settings.json. Claude Code then owns
      # session history / credentials / plugin cache inside the deepseek dir at
      # runtime, isolating sessions/memories between the two instances.
      deepseekFileAttrs = {
        "${ds.configDir}/CLAUDE.md".text = claudeContext;
        "${ds.configDir}/settings.json".source =
          config.lib.file.mkOutOfStoreSymlink "${cfg.configDir}/settings.json";
        "${ds.configDir}/skills/claude-code-home-manager".source = deepseekHmPlugin;
      }
      // lib.mapAttrs' (
        name: _: lib.nameValuePair "${ds.configDir}/agents/${name}.md" { source = claudeAgents.${name}; }
      ) claudeAgents
      // lib.mapAttrs' (
        name: _:
        lib.nameValuePair "${ds.configDir}/commands/${name}.md" { source = claudeCommands.${name}; }
      ) claudeCommands
      // lib.mapAttrs' (
        name: source:
        lib.nameValuePair "${ds.configDir}/skills/${name}" {
          source = mkPluginEntryDeepseek name source;
        }
      ) claudePlugins;
    in
    {
      options.dotagents.claudeDeepseek = {
        # Optional second Claude Code instance, "claude-deepseek". It renders
        # the SAME dotagents-derived content (skills/agents/commands/CLAUDE.md/
        # LSP, drawn from the hoisted bindings above) into a second config dir,
        # so session history and memory isolate between the two instances while
        # the content stays shared. settings.json is one shared writable file
        # (the deepseek dir's copy is a symlink to the primary's).
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to also render the claude-deepseek instance.";
        };
        configDir = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/.claude-deepseek";
          description = "Config dir for the claude-deepseek instance.";
        };
        baseUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://api.deepseek.com/anthropic";
          description = "Anthropic-compatible base URL exported by the claude-deepseek launcher.";
        };
        sops = lib.mkOption {
          type = sopsLib.mkType;
          default = { };
          description = ''
            Sops-backed secrets for claude-deepseek. Gate with
            `dotagents.claudeDeepseek.sops.enable`, then set
            `secrets.apiKey.key` (read into ANTHROPIC_AUTH_TOKEN by the
            launcher). Leave disabled to omit the token.
          '';
        };
        model = lib.mkOption {
          type = lib.types.str;
          default = "deepseek-v4-flash";
          description = "ANTHROPIC_MODEL / ANTHROPIC_DEFAULT_MODEL for the claude-deepseek launcher.";
        };
        modelPickerModels = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "deepseek-v4-flash"
            "deepseek-v4-pro"
            "deepseek-v4-flash-vision-exp"
          ];
          description = "Model options injected into the model picker via --settings.";
        };
        maxContextTokens = lib.mkOption {
          type = lib.types.str;
          default = "300000";
          description = "CLAUDE_CODE_MAX_CONTEXT_TOKENS for the claude-deepseek launcher.";
        };
      };

      config = {
        programs.claude-code = {
          enable = true;

          # Global context written to ~/.claude/CLAUDE.md, applied across every
          # Claude Code session. Content lives once in config.dotagents.context
          # (homeModules/dotagents.nix), shared with opencode.
          context = claudeContext;
          # Library catalog ∪ enabled Skill Sources (merged above into
          # `skills` / `claudePlugins`). Each key becomes a Claude plugin named
          # after the skill, referenced by its $out/skills/<name> directory.
          # Collection keys (layout "collection") are whole bundles
          # ($out/skills/ holds many constituent skills): they're rendered as
          # the package root (a whole plugin), not $out/skills/<name>. Skill
          # Source keys use default layout "skill".
          plugins = claudePlugins;
          commands = claudeCommands;
          # The subagents, converted for Claude Code via Adapter Emit from the
          # Common Model (Authoring Format agents + metadata.claude; inline
          # mcpServers derived from Instance MCP catalog by tool needs). The
          # github pair only when the github instance is enabled, and
          # explore-argocd only when the argocd instance is enabled). The
          # home-manager/claude-code module writes
          # them to ~/.claude/agents/<name>.md.
          agents = claudeAgents;
          # The upstream gopls-lsp/rust-analyzer-lsp marketplace plugins ship
          # with no .lsp.json manifest (anthropics/claude-plugins-official#379),
          # so their lspServers config in marketplace.json never actually
          # takes effect. Declaring the same servers here instead makes
          # home-manager synthesize a proper local plugin (.claude-plugin +
          # .lsp.json) that does work — pointed at the same gopls /
          # rust-analyzer packages installed by the golang and rust homeModules.
          lspServers = claudeLspServers;
          settings = claudeSettings;
          # No MCP servers in the main conversation. The shared server set
          # (config.dotagents.mcpServers, kept for reference above) is served to
          # subagents via inline `mcpServers:` frontmatter in their agent
          # files instead, so main-context stays free of MCP tool schemas.
          mcpServers = { };
        };

        # After every `home-manager switch`, replace the read-only
        # symlink with a real writable regular file seeded from the same
        # declared content, so Claude Code can write to it without crashing.
        home.file = lib.mkMerge [
          (lib.mkIf (cfg.settings != { } || cfg.marketplaces != { }) {
            "${cfg.configDir}/settings.json".force = true;
          })
          # The deepseek config dir is rendered directly via home.file (the
          # programs.claude-code module is a singleton). Guarded behind
          # ds.enable so a disabled feature never evaluates the deepseek
          # derivations.
          (lib.mkIf ds.enable deepseekFileAttrs)
        ];

        home.packages = lib.mkIf ds.enable [ deepseekLauncher ];

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
