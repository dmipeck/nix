# Common Model discovery — Authoring Format flat agents → parsed attrs.
# Consumed by Adapter Emit; unmigrated directory agents stay on the legacy path.
{ lib, frontmatterLib }:
let
  inherit (frontmatterLib) importMarkdown;

  # agentsDir → { <id> = { frontmatter, body, path }; }
  discoverAgents =
    agentsDir:
    let
      dirents = builtins.readDir agentsDir;
      legacyNames = builtins.attrNames (lib.filterAttrs (_: v: v == "directory") dirents);
      flatFiles = lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".md" n) dirents;
      flatNames = map (n: lib.removeSuffix ".md" n) (builtins.attrNames flatFiles);

      overlap = builtins.filter (n: builtins.elem n legacyNames) flatNames;
    in
    if overlap != [ ] then
      throw (
        "dotagents Common Model: agent exists as both directory and flat .md: "
        + lib.concatStringsSep ", " overlap
      )
    else
      lib.genAttrs flatNames (
        name:
        let
          path = agentsDir + "/${name}.md";
          parsed = importMarkdown path;
          fmName = parsed.frontmatter.name or null;
        in
        if fmName != name then
          throw "dotagents agent ${name}.md: frontmatter name (${toString fmName}) must equal filename stem"
        else
          parsed
          // {
            inherit path;
          }
      );

in
{
  inherit discoverAgents;
}
