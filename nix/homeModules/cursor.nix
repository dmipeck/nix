{ config, adapterEmit, ... }@flakeArgs:
let
  # Skill/plugin packages and Common Model agents are owned by nix/dotagents/;
  # captured once so the home-manager module below can reference them.
  agentSkills = flakeArgs.config.dotagents.skills;
  skillLayouts = flakeArgs.config.dotagents.skillLayouts;
  # Authoring Format agents → Common Model (Cursor Adapter Emit passthrough).
  commonAgents = flakeArgs.config.dotagents.commonModel.agents;
  cheapSubagents = flakeArgs.config.dotagents.cheapSubagents;
  # Common Model rules — Cursor Adapter Emit passthrough of authored `.mdc`.
  rules = flakeArgs.config.dotagents.rules;
  # Per-client default model + variation; this adapter reads the `cursor` client.
  models = flakeArgs.config.dotagents.models.cursor;
in
{
  # Thin adapter: maps Common Model skills / agents / MCP / rules onto Cursor
  # under ~/.cursor/. Agents: documented FM fields only (`metadata` stripped).
  # Skills copy/symlink as authored (`disable-model-invocation: true` = slash-only).
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
      # Skip collection bundles (constituents are separate keys). Skills with
      # `disable-model-invocation: true` in frontmatter are slash-only; that
      # flag is preserved as written in SKILL.md (no commands layer).
      # -----------------------------------------------------------------
      plainSkills = lib.filterAttrs (
        name: _: (skillLayouts.${name} or "skill") != "collection"
      ) agentSkills;

      skillFiles = lib.mapAttrs' (
        name: pkg: lib.nameValuePair ".cursor/skills/${name}" { source = "${pkg}/skills/${name}"; }
      ) plainSkills;

      # -----------------------------------------------------------------
      # Agents → ~/.cursor/agents/<name>.md
      # Common Model → Adapter Emit passthrough: documented Cursor FM fields
      # only (name, description, model, readonly, is_background). Metadata
      # stripped. Model defaults from dotagents.models.cursor when unset.
      # -----------------------------------------------------------------
      # Bake a variation into Cursor's bracket syntax when both are set
      # (e.g. composer-2.5[effort=high]); "inherit" and null variation stay
      # as the bare model id.
      withVariation =
        model: variation:
        if model == "inherit" || variation == null then model else "${model}[effort=${variation}]";

      cursorModelFor =
        name:
        let
          cheap = lib.elem name cheapSubagents;
        in
        # Cheap workers pin the subagent model; orchestrate uses the primary
        # model; every other agent inherits the session model.
        if cheap then
          withVariation models.subagent.model models.subagent.variation
        else if name == "orchestrate" then
          withVariation models.primary.model models.primary.variation
        else
          "inherit";

      renderAgent =
        name: agent:
        let
          model = cursorModelFor name;
          # Prefer authored top-level model; else inject adapter default.
          frontmatter =
            agent.frontmatter // lib.optionalAttrs (!(agent.frontmatter ? model)) { inherit model; };
          text = adapterEmit.emitCursorAgent (agent // { inherit frontmatter; });
        in
        pkgs.writeText "dotagents-${name}-agent-cursor" text;

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
      firebaseAgentNames = [
        "explore-firebase"
        "firebase"
      ];

      allCursorAgents = lib.mapAttrs renderAgent commonAgents;

      cursorAgents =
        (lib.removeAttrs allCursorAgents (
          githubAgentNames
          ++ gitlabAgentNames
          ++ argocdAgentNames
          ++ cloudflareAgentNames
          ++ cloudflareBindingsAgentNames
          ++ cloudflareObservabilityAgentNames
          ++ firebaseAgentNames
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
        )
        // lib.optionalAttrs config.dotagents.mcps.firebase.enable (
          lib.genAttrs firebaseAgentNames (n: allCursorAgents.${n})
        );

      agentFiles = lib.mapAttrs' (
        name: drv: lib.nameValuePair ".cursor/agents/${name}.md" { source = drv; }
      ) cursorAgents;

      # -----------------------------------------------------------------
      # Global rules → ~/.cursor/rules/dotagents.mdc (Authoring Format SoT).
      # Cursor Adapter Emit: passthrough of the authored Common Model path.
      # -----------------------------------------------------------------
      rulesFile = {
        ".cursor/rules/dotagents.mdc" = {
          source = rules.path;
        };
      };

      # Session env exports for "{file:...}" → "${env:VAR}" rewrites.
      fileRefExports = lib.concatMapStrings (ref: ''
        export ${ref.name}="$(<${ref.path})"
      '') allFileRefs;
    in
    {
      config = {
        home.file =
          skillFiles
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
