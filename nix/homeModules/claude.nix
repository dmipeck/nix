{ config, ... }@flakeArgs:
let
  # Skill/plugin packages are owned by nix/dotagents/ (skills/*.nix). `config`
  # here is flake-parts state (auto-imported under nix/); captured once so the
  # home-manager module below can reference the packages.
  skills = flakeArgs.config.dotagents.skills;
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
          plugins = {
            mcp-server-dev = skills.mcp-server-dev;
            skill-creator = skills.skill-creator;
            grafana-core = skills.grafana-core;
            grafana-lgtm = skills.grafana-lgtm;
            grafana-datasources = skills.grafana-datasources;
            stop-slop = skills.stop-slop;
            handoff = skills.handoff;
            grill-me = skills.grill-me;
            caveman = skills.caveman;
            skill-optimizer = skills.skill-optimizer;
            git-workflow = skills.git-workflow;
            commit = skills.commit;
            test = skills.test;
            comments = skills.comments;
            golang-api = "${skills.golang-api}/skills/golang-api";
            golang-cli = "${skills.golang-cli}/skills/golang-cli";
            golang-database = "${skills.golang-database}/skills/golang-database";
            golang-decoupling = "${skills.golang-decoupling}/skills/golang-decoupling";
            golang-layout = "${skills.golang-layout}/skills/golang-layout";
            golang-migration = "${skills.golang-migration}/skills/golang-migration";
            golang-query = "${skills.golang-query}/skills/golang-query";
            golang-testing = "${skills.golang-testing}/skills/golang-testing";
            postgres = "${skills.postgres}/skills/postgres";
          };
          commands = {
            set-budget = "${claudeStatuslineSrc}/.claude/commands/set-budget.md";
            # scaffold command file, built by dmipeck/agents and passed
            # through config.dotagents.commands (dotagents.nix).
            scaffold = config.dotagents.commands.scaffold;
          };
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
