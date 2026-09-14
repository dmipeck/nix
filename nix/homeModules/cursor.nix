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
      # Common Model + Instance is already Cursor wire shape. Adapter Emit
      # rewrites "{file:...}" → "${env:VAR}" and we export matching session
      # env vars from the sops-decrypted files.
      # -----------------------------------------------------------------
      # Strip Nix-only tool enums before Cursor emit.
      wireMcpServers = lib.mapAttrs (_: srv: builtins.removeAttrs srv [ "tools" ]) mcpServers;

      cursorMcp = adapterEmit.emitCursorMcp { mcpServers = wireMcpServers; };
      allFileRefs = adapterEmit.collectCursorMcpFileRefs { mcpServers = wireMcpServers; };

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
      # Global rules → ~/.cursor/rules/<stem>.mdc (Authoring Format SoT).
      # Cursor Adapter Emit: passthrough of each authored Common Model path.
      # -----------------------------------------------------------------
      rulesFile = lib.mapAttrs' (
        name: rule: lib.nameValuePair ".cursor/rules/${name}.mdc" { source = rule.path; }
      ) rules;

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
