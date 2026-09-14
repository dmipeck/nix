# MCP Server Definition dual-read — authored Cursor-shaped mcp.json + legacy
# Nix local/remote modules → Common Model mcpServers (Cursor wire shape).
# Tool allowlists stay Nix-side (not in authored mcp.json / Cursor emit).
{ lib }:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    optionalAttrs
    ;

  # Same class as lib.importJSON: pure eval-time, no IFD.
  importJSON = path: builtins.fromJSON (builtins.readFile path);

  importMcpJson =
    path:
    let
      raw = importJSON path;
    in
    raw.mcpServers or raw;

  # Map legacy Nix oauth → Cursor auth { CLIENT_ID, CLIENT_SECRET, scopes }.
  oauthToAuth =
    oauth:
    optionalAttrs (oauth != null && oauth.clientId != null) {
      auth = {
        CLIENT_ID = oauth.clientId;
      }
      // optionalAttrs (oauth.clientSecret != null) {
        CLIENT_SECRET = oauth.clientSecret;
      }
      // optionalAttrs (oauth.scope != null) {
        scopes = lib.splitString " " oauth.scope;
      };
    };

  # Convert one Nix Server Definition (type = local|remote) → Cursor shape.
  # Drops tools / mcpToolEnum — those remain Nix-only.
  nixServerToCursor =
    srv:
    if (srv.type or null) == "remote" then
      optionalAttrs ((srv.url or null) != null) { url = srv.url; }
      // optionalAttrs ((srv.headers or { }) != { }) { headers = srv.headers; }
      // oauthToAuth (srv.oauth or null)
    else
      {
        type = "stdio";
        command = srv.command;
        args = srv.args or [ ];
      }
      // optionalAttrs ((srv.env or { }) != { }) { env = srv.env; };

  # Dual-read: authored mcp.json is the baseline; Nix modules overlay the same
  # keys (so store-path commands / existing defs keep working) and contribute
  # Nix-only servers. Result is Cursor-shaped Common Model mcpServers.
  dualReadMcpServers =
    {
      authored,
      nixServers,
    }:
    let
      fromNix = mapAttrs (_: nixServerToCursor) nixServers;
    in
    authored // fromNix;

  # Apply MCP Instance overlays (enable / url / env / headers / auth).
  # enable = false drops the server; missing overlay leaves the definition.
  applyInstanceOverlay =
    instances: mcpServers:
    let
      step =
        name: srv:
        let
          inst = instances.${name} or null;
        in
        if inst == null then
          srv
        else if (inst.enable or true) == false then
          null
        else
          srv
          // optionalAttrs (inst ? url && inst.url != null) { url = inst.url; }
          // optionalAttrs (inst ? env) {
            env = (srv.env or { }) // inst.env;
          }
          // optionalAttrs (inst ? headers) {
            headers = (srv.headers or { }) // inst.headers;
          }
          // optionalAttrs (inst ? auth) {
            auth = (srv.auth or { }) // inst.auth;
          }
          // optionalAttrs (inst ? command) { command = inst.command; }
          // optionalAttrs (inst ? args) { args = inst.args; };
      merged = mapAttrs step mcpServers;
    in
    filterAttrs (_: v: v != null) merged;

in
{
  inherit
    importJSON
    importMcpJson
    nixServerToCursor
    dualReadMcpServers
    applyInstanceOverlay
    ;
}
