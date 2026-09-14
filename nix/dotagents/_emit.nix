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

  # Claude FM from shared fields + metadata.claude; optional model/effort and
  # derived mcpServers block (attrs → YAML under mcpServers).
  emitClaudeAgent =
    agent:
    {
      model ? null,
      effort ? null,
      mcpServers ? null,
      tools ? null,
    }:
    let
      fm = agent.frontmatter;
      cl = fm.metadata.claude or { };
      base = {
        name = fm.name;
        description = fm.description;
      }
      // optionalAttrs (tools != null || cl ? tools) {
        tools = if tools != null then tools else cl.tools;
      }
      // optionalAttrs (model != null) { inherit model; }
      // optionalAttrs (effort != null && effort != "") { inherit effort; }
      // optionalAttrs (mcpServers != null) { inherit mcpServers; }
      // (builtins.removeAttrs cl [ "tools" ]);
    in
    renderMarkdown claudeAgentKeys base agent.body;

  # Cursor mcp.json wire shape: Common Model mcpServers already Cursor-shaped.
  emitCursorMcp = mcp: {
    mcpServers = mcp.mcpServers or mcp;
  };

  emitCursorMcpJson = mcp: builtins.toJSON (emitCursorMcp mcp);

in
{
  inherit
    emitCursorAgent
    emitOpenCodeAgent
    emitClaudeAgent
    emitCursorMcp
    emitCursorMcpJson
    cursorAgentKeys
    ;
}
