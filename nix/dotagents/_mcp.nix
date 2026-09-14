# MCP Server Definitions — authored Cursor-shaped mcp.json is the single SoT.
# Instance overlays (enable / url / env / headers / auth / command / args) apply
# before Adapter Emit. Tool allowlists stay Nix-side (not in mcp.json / Cursor emit).
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

  # Apply MCP Instance overlays (enable / url / env / headers / auth / command / args).
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

  # Resolve authored stdio `command` names to store paths via mcpPackages
  # (keyed by the same binary name as in mcp.json, e.g. "mcp-nixos").
  resolveMcpPackages =
    mcpPackages: mcpServers:
    mapAttrs (
      _: srv:
      let
        cmd = srv.command or null;
        pkg = if cmd != null then mcpPackages.${cmd} or null else null;
      in
      if pkg == null then srv else srv // { command = "${pkg}/bin/${cmd}"; }
    ) mcpServers;

  # POSIX ERE (builtins.match): literal braces via character classes — "\{"
  # is invalid and throws at eval time.
  fileRefMatch = builtins.match ".*[{]file:([^}]+)[}].*";

  # Stable env var name for a "{file:...}" value keyed by server + field.
  fileEnvName =
    server: field:
    "DOTAGENTS_CURSOR_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] server)}_${lib.toUpper field}";

  # Rewrite one string; return { value, refs } where refs are { name, path }.
  rewriteFileRef =
    server: field: val:
    let
      m = if builtins.isString val then fileRefMatch val else null;
    in
    if m == null then
      {
        value = val;
        refs = [ ];
      }
    else
      let
        path = builtins.head m;
        name = fileEnvName server field;
      in
      {
        value = lib.replaceStrings [ "{file:${path}}" ] [ "\${env:${name}}" ] val;
        refs = [
          {
            inherit name path;
          }
        ];
      };

  # Rewrite {file:} → ${env:…} across Cursor-shaped mcpServers (headers + auth).
  # Returns { mcpServers, fileRefs }.
  rewriteFileRefsForCursor =
    mcpServers:
    let
      step =
        server: srv:
        let
          headerSteps = mapAttrs (
            hname: hval: rewriteFileRef server (lib.replaceStrings [ "-" ] [ "_" ] hname) hval
          ) (srv.headers or { });
          auth = srv.auth or { };
          secretStep =
            if auth ? CLIENT_SECRET then
              rewriteFileRef server "CLIENT_SECRET" auth.CLIENT_SECRET
            else
              {
                value = null;
                refs = [ ];
              };
          newHeaders = mapAttrs (_: s: s.value) headerSteps;
          newAuth =
            if auth == { } then
              null
            else
              auth // optionalAttrs (auth ? CLIENT_SECRET) { CLIENT_SECRET = secretStep.value; };
          refs = lib.concatLists (map (s: s.refs) (builtins.attrValues headerSteps)) ++ secretStep.refs;
        in
        {
          server =
            srv
            // optionalAttrs (srv ? headers) { headers = newHeaders; }
            // optionalAttrs (newAuth != null) { auth = newAuth; };
          inherit refs;
        };
      mapped = mapAttrs step mcpServers;
    in
    {
      mcpServers = mapAttrs (_: s: s.server) mapped;
      fileRefs = lib.concatLists (map (s: s.refs) (builtins.attrValues mapped));
    };

in
{
  inherit
    importJSON
    importMcpJson
    applyInstanceOverlay
    resolveMcpPackages
    rewriteFileRefsForCursor
    fileRefMatch
    fileEnvName
    ;
}
