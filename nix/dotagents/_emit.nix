# Adapter Emit — render Common Model agents / MCP into consumer dialects.
# Cursor = passthrough (documented agent fields only; metadata stripped).
# OpenCode / Claude = convert from Common Model + metadata nests.
{ lib, frontmatterLib }:
let
  inherit (frontmatterLib) toYAMLOrdered;
  inherit (lib) optionalAttrs filterAttrs;

  # Cursor-documented agent frontmatter fields (ADR-0001).
  cursorAgentKeys = [
    "name"
    "description"
    "model"
    "readonly"
    "is_background"
  ];

  openCodeAgentKeys = [
    "description"
    "mode"
    "temperature"
    "permission"
    "tools"
    "model"
    "variant"
  ];

  claudeAgentKeys = [
    "name"
    "description"
    "tools"
    "model"
    "effort"
    "mcpServers"
    "permission"
  ];

  pick = keys: attrs: filterAttrs (k: _: builtins.elem k keys) attrs;

  renderMarkdown =
    keyOrder: fm: body:
    let
      yaml = toYAMLOrdered keyOrder fm;
      # Normalize body to lead with a blank line after the closing fence.
      normalized =
        if body == "" then
          "\n"
        else
          let
            withLead = if lib.hasPrefix "\n" body then body else "\n" + body;
          in
          if lib.hasSuffix "\n" withLead then withLead else withLead + "\n";
    in
    "---\n" + yaml + "\n---\n" + normalized;

  # agent :: { frontmatter, body }
  emitCursorAgent =
    agent:
    let
      fm = pick cursorAgentKeys agent.frontmatter;
    in
    renderMarkdown cursorAgentKeys fm agent.body;

  # Hoist metadata.opencode to top-level OpenCode FM; inject model/variant
  # when absent. Shared description stays top-level.
  emitOpenCodeAgent =
    agent:
    {
      model ? null,
      variant ? null,
    }:
    let
      fm = agent.frontmatter;
      oc = fm.metadata.opencode or { };
      base = {
        description = fm.description;
      }
      // oc;
      withModel = if model != null && !(base ? model) then base // { inherit model; } else base;
      withVariant =
        if variant != null && !(withModel ? variant) then withModel // { inherit variant; } else withModel;
    in
    renderMarkdown openCodeAgentKeys withVariant agent.body;

  # Infer MCP server names an agent needs from Claude tools strings/lists and
  # OpenCode tool keys (server_* / mcp__server__*). Longest server name wins
  # so cloudflare-bindings beats cloudflare.
  inferClaudeMcpServerNames =
    agent: availableServers:
    let
      fm = agent.frontmatter;
      cl = fm.metadata.claude or { };
      oc = fm.metadata.opencode or { };
      servers = builtins.sort (a: b: builtins.stringLength a > builtins.stringLength b) availableServers;

      fromMcpToken =
        tok:
        # Prefer longest available server prefix inside mcp__…__…
        lib.findFirst (
          s: lib.hasPrefix "mcp__${s}__" tok || tok == "mcp__${s}__*"
        ) null servers;

      fromClaudeTools =
        tools:
        if builtins.isString tools then
          lib.filter (s: s != null) (
            map fromMcpToken (lib.splitString ", " (lib.replaceStrings [ ",  " ] [ ", " ] tools))
          )
        else if builtins.isList tools then
          lib.filter (s: s != null) (map (t: if builtins.isString t then fromMcpToken t else null) tools)
        else
          [ ];

      fromOcKey =
        key:
        if lib.hasPrefix "mcp__" key then
          fromMcpToken key
        else
          lib.findFirst (s: key == "${s}_*" || lib.hasPrefix "${s}_" key) null servers;

      fromOc = lib.filter (s: s != null) (map fromOcKey (builtins.attrNames (oc.tools or { })));

      # Empty claude.tools list means "derive" — still consult opencode tools.
      clTools = cl.tools or null;
      fromCl =
        if clTools == null || clTools == [ ] then [ ] else fromClaudeTools clTools;
    in
    lib.unique (fromCl ++ fromOc);

  # Pick Claude-wire mcpServers attrs for an agent from a catalog.
  selectClaudeMcpServers =
    agent: catalog:
    let
      names = inferClaudeMcpServerNames agent (builtins.attrNames catalog);
    in
    if names == [ ] then null else lib.getAttrs names catalog;

  # True when bash is a Claude fallback (gh/glab allow in Metadata).
  claudeNeedsBash =
    agent:
    let
      cl = agent.frontmatter.metadata.claude or { };
      oc = agent.frontmatter.metadata.opencode or { };
      allow = cl.permission.allow or [ ];
      bash = oc.permission.bash or { };
      allowBash =
        builtins.any (p: builtins.isString p && lib.hasPrefix "Bash(" p) allow
        || builtins.any (k: k != "*" && bash.${k} == "allow") (builtins.attrNames bash);
    in
    allowBash;

  # OpenCode tool key → Claude mcp__server__tool (or wildcard).
  opencodeToolToClaude =
    availableServers: key:
    let
      servers = builtins.sort (a: b: builtins.stringLength a > builtins.stringLength b) availableServers;
    in
    if lib.hasPrefix "mcp__" key then
      key
    else
      let
        s = lib.findFirst (srv: key == "${srv}_*" || lib.hasPrefix "${srv}_" key) null servers;
      in
      if s == null then
        null
      else if key == "${s}_*" then
        "mcp__${s}__*"
      else
        "mcp__${s}__${lib.removePrefix "${s}_" key}";

  # Claude tools: authored metadata.claude.tools wins when non-empty; empty
  # list/null → derive from metadata.opencode.tools (+ Bash when needed).
  deriveClaudeTools =
    agent: availableServers:
    let
      cl = agent.frontmatter.metadata.claude or { };
      oc = agent.frontmatter.metadata.opencode or { };
      authored = cl.tools or null;
      fromAuthored =
        if authored == null || authored == [ ] then
          null
        else if builtins.isString authored then
          authored
        else if builtins.isList authored then
          lib.concatStringsSep ", " authored
        else
          null;
      derivedKeys = lib.filter (t: t != null) (
        map (opencodeToolToClaude availableServers) (builtins.attrNames (oc.tools or { }))
      );
      withBash =
        if claudeNeedsBash agent && !(builtins.elem "Bash" derivedKeys) then
          [ "Bash" ] ++ derivedKeys
        else
          derivedKeys;
    in
    if fromAuthored != null then
      fromAuthored
    else if derivedKeys == [ ] then
      null
    else
      lib.concatStringsSep ", " withBash;

  # Claude FM from shared fields + metadata.claude; optional model/effort and
  # derived mcpServers block (attrs → YAML under mcpServers).
  # Empty metadata.claude.tools ([]) means derive — omit unless `tools` passed.
  emitClaudeAgent =
    agent:
    {
      model ? null,
      effort ? null,
      mcpServers ? null,
      tools ? null,
      permission ? null,
      # Full Claude-wire catalog; when set and mcpServers is null, select by
      # agent tool needs (Common Model / Instance MCP).
      mcpCatalog ? null,
      # Server names for tools derivation (defaults to mcpCatalog names).
      availableServers ? null,
    }:
    let
      fm = agent.frontmatter;
      cl = fm.metadata.claude or { };
      catalog = if mcpCatalog != null then mcpCatalog else { };
      servers =
        if availableServers != null then
          availableServers
        else
          builtins.attrNames catalog;
      derivedTools = deriveClaudeTools agent servers;
      derivedMcp =
        if mcpServers != null then
          mcpServers
        else if mcpCatalog != null then
          selectClaudeMcpServers agent catalog
        else
          null;
      clTools = cl.tools or null;
      clToolsAuthored = if clTools == null || clTools == [ ] then null else clTools;
      effectiveTools = if tools != null then tools else if derivedTools != null then derivedTools else clToolsAuthored;
      base = {
        name = fm.name;
        description = fm.description;
      }
      // optionalAttrs (effectiveTools != null) { tools = effectiveTools; }
      // optionalAttrs (model != null) { inherit model; }
      // optionalAttrs (effort != null && effort != "") { inherit effort; }
      // optionalAttrs (derivedMcp != null) { mcpServers = derivedMcp; }
      // optionalAttrs (permission != null || cl ? permission) {
        permission = if permission != null then permission else cl.permission;
      }
      // (builtins.removeAttrs cl [
        "tools"
        "permission"
      ]);
    in
    renderMarkdown claudeAgentKeys base agent.body;

  # Cursor mcp.json wire shape: Common Model mcpServers already Cursor-shaped.
  emitCursorMcp = mcp: {
    mcpServers = mcp.mcpServers or mcp;
  };

  emitCursorMcpJson = mcp: builtins.toJSON (emitCursorMcp mcp);

  # Cursor .mdc rule fields (Authoring Format SoT). alwaysApply is required for
  # global rules; description is optional but authored for clarity.
  cursorRulesKeys = [
    "description"
    "globs"
    "alwaysApply"
  ];

  # rules :: { frontmatter, body }
  emitCursorRules =
    rules:
    let
      fm = pick cursorRulesKeys rules.frontmatter;
    in
    renderMarkdown cursorRulesKeys fm rules.body;

  # OpenCode / Claude: body only (AGENTS.md / CLAUDE.md), no .mdc wrap.
  emitRulesBody =
    rules:
    let
      body = rules.body;
    in
    if body == "" then
      ""
    else if lib.hasSuffix "\n" body then
      body
    else
      body + "\n";

  emitOpenCodeRules = emitRulesBody;
  emitClaudeRules = emitRulesBody;

in
{
  inherit
    emitCursorAgent
    emitOpenCodeAgent
    emitClaudeAgent
    emitCursorMcp
    emitCursorMcpJson
    emitCursorRules
    emitOpenCodeRules
    emitClaudeRules
    emitRulesBody
    inferClaudeMcpServerNames
    selectClaudeMcpServers
    deriveClaudeTools
    claudeNeedsBash
    opencodeToolToClaude
    cursorAgentKeys
    cursorRulesKeys
    ;
}
