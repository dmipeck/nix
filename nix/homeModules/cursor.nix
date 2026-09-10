{ config, ... }@flakeArgs:
let
  # Skill/plugin packages and agent definitions are owned by nix/dotagents/;
  # captured once so the home-manager module below can reference them.
  agentSkills = flakeArgs.config.dotagents.skills;
  skillLayouts = flakeArgs.config.dotagents.skillLayouts;
  skillCommands = flakeArgs.config.dotagents.skillCommands;
  agents = flakeArgs.config.dotagents.agents;
  cheapSubagents = flakeArgs.config.dotagents.cheapSubagents;
  # Per-client default model + variation; this adapter reads the `cursor` client.
  models = flakeArgs.config.dotagents.models.cursor;
in
{
  # Thin adapter: maps neutral dotagents skills / agents / commands / MCP /
  # context onto Cursor's config dialect under ~/.cursor/.
  flake.homeModules.cursor =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      mcpServers = config.dotagents.mcpServers;
      jsonFormat = pkgs.formats.json { };

      # -----------------------------------------------------------------
      # MCP → ~/.cursor/mcp.json
      # Cursor dialect: stdio uses command/args/env; remote uses url/headers
      # and optional auth { CLIENT_ID, CLIENT_SECRET, scopes }. Secrets that
      # arrive as opencode's "{file:/path}" are rewritten to "${env:VAR}" and
      # the matching env var is exported from the sops-decrypted file at
      # session start (Cursor has no {file:} substitution).
      # -----------------------------------------------------------------
      # POSIX ERE (builtins.match): literal braces via character classes — "\{"
      # is invalid and throws at eval time.
      fileRefMatch = builtins.match ".*[{]file:([^}]+)[}].*";

      # Stable env var name for a "{file:...}" value keyed by server + field.
      fileEnvName =
        server: field:
        "DOTAGENTS_CURSOR_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] server)}_${lib.toUpper field}";

      collectFileRefs =
        server: srv:
        let
          fromHeaders = lib.mapAttrsToList (
            hname: hval:
            let
              m = fileRefMatch hval;
            in
            if m == null then
              null
            else
              {
                name = fileEnvName server (lib.replaceStrings [ "-" ] [ "_" ] hname);
                path = builtins.head m;
              }
          ) srv.headers;
          fromOauth =
            if srv.oauth != null && srv.oauth.clientSecret != null then
              let
                m = fileRefMatch srv.oauth.clientSecret;
              in
              if m == null then
                [ ]
              else
                [
                  {
                    name = fileEnvName server "CLIENT_SECRET";
                    path = builtins.head m;
                  }
                ]
            else
              [ ];
        in
        lib.filter (x: x != null) fromHeaders ++ fromOauth;

      allFileRefs = lib.concatLists (lib.mapAttrsToList collectFileRefs mcpServers);

      # Rewrite a single header value; derive the env name from the header key.
      rewriteHeader =
        server: hname: hval:
        let
          m = fileRefMatch hval;
        in
        if m == null then
          hval
        else
          lib.replaceStrings
            [ "{file:${builtins.head m}}" ]
            [
              "\${env:${fileEnvName server (lib.replaceStrings [ "-" ] [ "_" ] hname)}}"
            ]
            hval;

      toCursorMcp =
        name: srv:
        if srv.type == "remote" then
          {
            url = srv.url;
          }
          // lib.optionalAttrs (srv.headers != { }) {
            headers = lib.mapAttrs (rewriteHeader name) srv.headers;
          }
          // lib.optionalAttrs (srv.oauth != null && srv.oauth.clientId != null) {
            auth = {
              CLIENT_ID = srv.oauth.clientId;
            }
            // lib.optionalAttrs (srv.oauth.clientSecret != null) {
              CLIENT_SECRET =
                let
                  m = fileRefMatch srv.oauth.clientSecret;
                in
                if m == null then srv.oauth.clientSecret else "\${env:${fileEnvName name "CLIENT_SECRET"}}";
            }
            // lib.optionalAttrs (srv.oauth.scope != null) {
              scopes = lib.splitString " " srv.oauth.scope;
            };
          }
        else
          {
            type = "stdio";
            command = srv.command;
            args = srv.args;
          }
          // lib.optionalAttrs (srv.env != { }) { env = srv.env; };

      cursorMcp = {
        mcpServers = lib.mapAttrs toCursorMcp mcpServers;
      };

      # -----------------------------------------------------------------
      # Skills → ~/.cursor/skills/<name>/
      # Skip collection bundles (constituents are separate keys) and skills
      # listed in skillCommands (those become slash-only skills below).
      # -----------------------------------------------------------------
      plainSkills = lib.filterAttrs (
        name: _: (skillLayouts.${name} or "skill") != "collection" && !(lib.elem name skillCommands)
      ) agentSkills;

      skillFiles = lib.mapAttrs' (
        name: pkg: lib.nameValuePair ".cursor/skills/${name}" { source = "${pkg}/skills/${name}"; }
      ) plainSkills;

      # -----------------------------------------------------------------
      # Commands → ~/.cursor/skills/<name>/SKILL.md with
      # disable-model-invocation: true (Cursor's slash-command dialect;
      # .cursor/commands/ is legacy).
      #
      # - skillCommands: hard-copy the skill body (ADR); omitted from
      #   plainSkills above so slash is the only path.
      # - other commands that share a skill name: skip — the skill is already
      #   slash-invokable as /<name>, and emitting both would collide on
      #   ~/.cursor/skills/<name>.
      # - command-only names: convert the command markdown.
      # -----------------------------------------------------------------
      commandSkillFiles =
        lib.mapAttrs'
          (
            name: cmd:
            let
              isSkillCommand =
                (lib.elem name skillCommands)
                && (agentSkills ? ${name})
                && (skillLayouts.${name} or "skill") == "skill";
              src = if isSkillCommand then "${agentSkills.${name}}/skills/${name}/SKILL.md" else cmd;
            in
            lib.nameValuePair ".cursor/skills/${name}/SKILL.md" {
              source = pkgs.runCommand "dotagents-${name}-cursor-command" { } ''
                mkdir -p "$(dirname "$out")"
                {
                  # Ensure name + disable-model-invocation sit in frontmatter; keep
                  # the body (and any existing description) intact.
                  awk -v name="${name}" '
                    BEGIN { in_fm=0 }
                    NR==1 && /^---$/ { in_fm=1; print; print "name: " name; print "disable-model-invocation: true"; next }
                    in_fm && /^---$/ { in_fm=0; print; next }
                    in_fm && /^name:/ { next }
                    in_fm && /^disable-model-invocation:/ { next }
                    { print }
                  ' ${src}
                } > "$out"
              '';
            }
          )
          (
            lib.filterAttrs (
              name: _:
              (lib.elem name skillCommands)
              || !((agentSkills ? ${name}) && (skillLayouts.${name} or "skill") == "skill")
            ) config.dotagents.commands
          );

      # -----------------------------------------------------------------
      # Agents → ~/.cursor/agents/<name>.md
      # Cursor frontmatter: name, description, model, optional readonly.
      # Opencode mode/permission/tools blocks are stripped; body kept.
      # -----------------------------------------------------------------
      readonlyAgents = [
        "explore-nix"
        "explore-git"
        "explore-github"
        "explore-gitlab"
        "explore-argocd"
        "explore-cloudflare"
        "explore-cloudflare-bindings"
        "explore-cloudflare-observability"
        "export-kubernetes"
      ];

      # Hand-tuned descriptions (opencode frontmatter uses folded `>-` scalars
      # that are awkward to extract in Nix). Keep in sync with claude.nix.
      agentDescriptions = {
        nix = "Applies and verifies nix configuration changes on this machine — nixos-rebuild, home-manager, nix build/flake/profile/store, and nix-collect-garbage. Read-only exploration belongs to explore-nix.";
        "explore-nix" =
          "Explores nix and nixos configurations — this repo's flake and modules, nixpkgs/home-manager options, package versions. Read-only.";
        github = "Full GitHub development assistant — repos, PRs, issues, Actions. Write-capable.";
        "explore-github" =
          "Answers questions about git repositories via the github MCP read tools. Read-only.";
        gitlab = "Write-capable GitLab assistant — projects, issues, MRs, pipelines via the gitlab MCP server.";
        "explore-gitlab" = "Answers questions about GitLab via the gitlab MCP read tools. Read-only.";
        cloudflare = "Write-capable Cloudflare assistant via the cloudflare MCP server (docs, search, execute).";
        "explore-cloudflare" =
          "Answers Cloudflare API/feature questions via the cloudflare MCP read tools. Read-only.";
        "cloudflare-bindings" =
          "Manages Cloudflare Workers bindings (KV, Workers, R2, D1, Hyperdrive). Write-capable.";
        "explore-cloudflare-bindings" =
          "Answers questions about Cloudflare Workers bindings state. Read-only.";
        "explore-cloudflare-observability" =
          "Queries worker logs, metrics and schema via cloudflare-observability. Read-only.";
        "export-kubernetes" =
          "Answers questions about a Kubernetes cluster via the kubernetes MCP server. Read-only.";
        "explore-argocd" = "Answers questions about ArgoCD via the argocd MCP server. Read-only.";
        orchestrate = "Plans multi-step work, delegates every unit to the right subagent, tracks progress, and assembles results. Default primary agent.";
        test = "Runs the test suite for one testing ecosystem and reports pass/fail. Never takes corrective action.";
        commit = "Reviews pending changes, decides commit boundaries, and writes conventional + caveman-compressed commit messages.";
        format = "Runs repository formatters and fixes formatting issues across ecosystems. Write-capable.";
        lint = "Runs repository linters and fixes lint issues across ecosystems. Write-capable.";
        "explore-git" =
          "Answers questions about the current git repository using local git commands. Read-only.";
        git = "Full git assistant — read repo state and perform git operations. Write-capable.";
      };

      agentDescription =
        name:
        agentDescriptions.${name} or (
          let
            m = builtins.match ".*description:[ \t]*([^\n]*)[\n\r].*" (builtins.readFile agents.${name});
          in
          if m == null then name else builtins.head m
        );

      cursorAgent =
        name: description: model: readonly:
        let
          frontmatter = lib.concatStringsSep "\n" (
            [
              "---"
              "name: ${name}"
              # Quote descriptions — several contain `: ` which plain YAML
              # scalars would misparse as a mapping separator.
              "description: ${builtins.toJSON description}"
            ]
            ++ lib.optional (model != "" && model != "inherit") "model: ${model}"
            ++ lib.optional (model == "inherit") "model: inherit"
            ++ lib.optional readonly "readonly: true"
            ++ [ "---" ]
          );
        in
        pkgs.runCommand "dotagents-${name}-agent-cursor" { } ''
          mkdir -p "$(dirname "$out")"
          {
            cat <<'EOF'
          ${frontmatter}

          EOF
            # Drop the shared file's opencode frontmatter block, keep the body.
            awk 'NR==1 && /^---$/{front=1; next} front && /^---$/{front=0; next} !front' ${agents.${name}}
          } > "$out"
        '';

      # Bake a variation into Cursor's bracket syntax when both are set
      # (e.g. composer-2.5[effort=high]); "inherit" and null variation stay
      # as the bare model id.
      withVariation =
        model: variation:
        if model == "inherit" || variation == null then model else "${model}[effort=${variation}]";

      renderAgent =
        name:
        let
          cheap = lib.elem name cheapSubagents;
          # Cheap workers pin the subagent model; orchestrate uses the primary
          # model; every other agent inherits the session model.
          model =
            if cheap then
              withVariation models.subagent.model models.subagent.variation
            else if name == "orchestrate" then
              withVariation models.primary.model models.primary.variation
            else
              "inherit";
        in
        cursorAgent name (agentDescription name) model (lib.elem name readonlyAgents);

      githubAgentNames = [
        "explore-github"
        "github"
      ];
      gitlabAgentNames = [
        "explore-gitlab"
        "gitlab"
      ];
      argocdAgentNames = [ "explore-argocd" ];
      cloudflareAgentNames = [
        "explore-cloudflare"
        "cloudflare"
      ];
      cloudflareBindingsAgentNames = [
        "explore-cloudflare-bindings"
        "cloudflare-bindings"
      ];
      cloudflareObservabilityAgentNames = [ "explore-cloudflare-observability" ];

      allCursorAgents = lib.mapAttrs (name: _: renderAgent name) agents;

      cursorAgents =
        (lib.removeAttrs allCursorAgents (
          githubAgentNames
          ++ gitlabAgentNames
          ++ argocdAgentNames
          ++ cloudflareAgentNames
          ++ cloudflareBindingsAgentNames
          ++ cloudflareObservabilityAgentNames
        ))
        // lib.optionalAttrs config.dotagents.mcps.github.enable (
          lib.genAttrs githubAgentNames (n: allCursorAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.argocd.enable (
          lib.genAttrs argocdAgentNames (n: allCursorAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.gitlab.enable (
          lib.genAttrs gitlabAgentNames (n: allCursorAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.cloudflare.enable (
          lib.genAttrs cloudflareAgentNames (n: allCursorAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.cloudflare.bindings.enable (
          lib.genAttrs cloudflareBindingsAgentNames (n: allCursorAgents.${n})
        )
        // lib.optionalAttrs config.dotagents.mcps.cloudflare.observability.enable (
          lib.genAttrs cloudflareObservabilityAgentNames (n: allCursorAgents.${n})
        );

      agentFiles = lib.mapAttrs' (
        name: drv: lib.nameValuePair ".cursor/agents/${name}.md" { source = drv; }
      ) cursorAgents;

      # -----------------------------------------------------------------
      # Global context → ~/.cursor/rules/dotagents.mdc (alwaysApply).
      # Cursor has no global AGENTS.md; user/project rules cover this.
      # -----------------------------------------------------------------
      rulesFile = {
        ".cursor/rules/dotagents.mdc" = {
          text = ''
            ---
            alwaysApply: true
            description: Shared dotagents global agent instructions
            ---

            ${config.dotagents.context}
          '';
        };
      };

      # Session env exports for "{file:...}" → "${env:VAR}" rewrites.
      fileRefExports = lib.concatMapStrings (ref: ''
        export ${ref.name}="$(<${ref.path})"
      '') allFileRefs;
    in
    {
      options.cursor.enable = lib.mkEnableOption "Cursor as a dotagents target (skills, agents, commands, MCP, rules under ~/.cursor/)";

      config = lib.mkIf config.cursor.enable {
        home.file =
          skillFiles
          // commandSkillFiles
          // agentFiles
          // rulesFile
          // {
            ".cursor/mcp.json".source = jsonFormat.generate "cursor-mcp.json" cursorMcp;
          };

        # Export sops-backed secrets referenced from mcp.json into the user
        # session so Cursor's ${env:VAR} interpolation can resolve them.
        home.sessionVariablesExtra = lib.mkIf (allFileRefs != [ ]) fileRefExports;
      };
    };
}
