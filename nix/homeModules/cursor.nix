{ config, adapterEmit, ... }@flakeArgs:
let
  # Skill/plugin packages and Common Model agents are owned by nix/dotagents/;
  # captured once so the home-manager module below can reference them.
  # Adapters merge enabled Skill Sources at HM eval (see agentSkills below).
  librarySkills = flakeArgs.config.dotagents.skills;
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
      hasFileRefs = allFileRefs != [ ];
      fileRefNames = map (ref: ref.name) allFileRefs;

      # -----------------------------------------------------------------
      # Skills → ~/.cursor/skills/<name>/
      # Library catalog ∪ enabled Skill Sources (fail on duplicate ids).
      # Skip collection bundles (constituents are separate keys). Skills with
      # `disable-model-invocation: true` in frontmatter are slash-only; that
      # flag is preserved as written in SKILL.md (no commands layer).
      # -----------------------------------------------------------------
      mergeSkillCatalog = (import ./_merge-skill-catalog.nix { inherit lib; }).mergeSkillCatalog;
      agentSkills = mergeSkillCatalog librarySkills config.dotagents.skillSources;

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
      giteaAgentNames = [
        "explore-gitea"
        "gitea"
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
          ++ giteaAgentNames
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
        // lib.optionalAttrs config.dotagents.mcps.gitea.enable (
          lib.genAttrs giteaAgentNames (n: allCursorAgents.${n})
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

      # WHY sticky-empty race: hm-session-vars.sh is guarded by
      # __HM_SESS_VARS_SOURCED=1 (sourced once). Inline
      # `export VAR=$(</sops/path)` before sops-nix materialises the file
      # sticks empty forever; Cursor `${env:VAR}` then sends empty Bearer.
      # Guarded loads (`[ -s path ]`) never export empty; shell init + CLI
      # wrap + systemd oneshot re-apply once secrets exist.
      mcpEnvScriptPath = "${config.xdg.configHome}/dotagents/cursor-mcp-env.sh";
      mcpEnvScriptText = lib.concatMapStrings (ref: ''
        [ -s ${ref.path} ] && export ${ref.name}="$(${pkgs.coreutils}/bin/tr -d '\n' < ${ref.path})"
      '') allFileRefs;

      # Push non-empty secrets into the systemd user manager (and dbus
      # activation env) after sops-nix, so GUI Cursor / user units see them.
      mcpEnvSystemdScript = pkgs.writeShellScript "dotagents-cursor-mcp-env" (
        ''
          systemctl="${config.systemd.user.systemctlPath}"
          vars=()
        ''
        + lib.concatMapStrings (ref: ''
          if [ -s ${lib.escapeShellArg ref.path} ]; then
            value="$(${pkgs.coreutils}/bin/tr -d '\n' < ${lib.escapeShellArg ref.path})"
            export ${ref.name}="$value"
            "$systemctl" --user set-environment "${ref.name}=$value"
            vars+=(${lib.escapeShellArg ref.name})
          fi
        '') allFileRefs
        + ''
          if [ "''${#vars[@]}" -gt 0 ]; then
            ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd "''${vars[@]}"
          fi
        ''
      );

      sourceMcpEnv = ''
        # Re-load Cursor MCP sops env when secrets exist (undo sticky empties
        # from an early hm-session-vars source before sops-nix was ready).
        [ -f ${lib.escapeShellArg mcpEnvScriptPath} ] && . ${lib.escapeShellArg mcpEnvScriptPath}
      '';
    in
    {
      config = lib.mkMerge [
        {
          home.file =
            skillFiles
            // agentFiles
            // rulesFile
            // {
              ".cursor/mcp.json".source = jsonFormat.generate "cursor-mcp.json" cursorMcp;
            };
        }

        (lib.mkIf hasFileRefs {
          # Guarded per-var loads; sourced by sessionVariablesExtra, shells,
          # CLI wrap (cursor-cli.nix), and the systemd oneshot below.
          xdg.configFile."dotagents/cursor-mcp-env.sh".text = mcpEnvScriptText;

          # Source the script instead of unguarded inline exports so a
          # pre-sops first source does not sticky-export empties.
          home.sessionVariablesExtra = ''
            . ${lib.escapeShellArg mcpEnvScriptPath}
          '';

          systemd.user.services.dotagents-cursor-mcp-env = {
            Unit = {
              Description = "Load Cursor MCP sops secrets into systemd user environment";
              After = [ "sops-nix.service" ];
            };
            Service = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${mcpEnvSystemdScript}";
            };
            Install.WantedBy = [ "default.target" ];
          };

          # sops-nix's HM hook can leave a stale unit; after linkGeneration:
          # daemon-reload, restart sops-nix, wait for files, then push env.
          home.activation.cursorMcpEnv = lib.hm.dag.entryAfter [ "linkGeneration" "sops-nix" ] ''
            systemctl="${config.systemd.user.systemctlPath}"
            systemctlStatus="$($systemctl --user is-system-running 2>&1 || true)"
            if [[ $systemctlStatus == 'running' || $systemctlStatus == 'degraded' ]]; then
              $systemctl daemon-reload --user
              $systemctl restart --user sops-nix
            fi
            ${lib.concatMapStrings (ref: ''
              secret_file=${lib.escapeShellArg ref.path}
              for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
                if [ -f "$secret_file" ]; then
                  break
                fi
                ${pkgs.coreutils}/bin/sleep 0.1
              done
              if [ ! -f "$secret_file" ]; then
                echo "cursor MCP env: timed out waiting for sops secret at $secret_file" >&2
                exit 1
              fi
            '') allFileRefs}
            if [[ $systemctlStatus == 'running' || $systemctlStatus == 'degraded' ]]; then
              $systemctl restart --user dotagents-cursor-mcp-env.service
            fi
            unset systemctlStatus
            # Apply into this activation's environment + dbus for already-open
            # sessions (oneshot covers systemd user manager).
            if [ -f ${lib.escapeShellArg mcpEnvScriptPath} ]; then
              . ${lib.escapeShellArg mcpEnvScriptPath}
              ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd ${lib.concatStringsSep " " fileRefNames}
            fi
          '';

          programs.bash.initExtra = lib.mkIf config.programs.bash.enable (lib.mkAfter sourceMcpEnv);
          programs.zsh.initExtra = lib.mkIf config.programs.zsh.enable (lib.mkAfter sourceMcpEnv);
        })
      ];
    };
}
