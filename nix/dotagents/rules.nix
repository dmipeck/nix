# Global rules — Cursor Authoring Format SoT (`rules/*.mdc`).
# Parsed into the Common Model via Frontmatter Parser; Adapter Emit:
# Cursor = passthrough each .mdc, OpenCode/Claude = concatenated bodies.
{ lib, frontmatterLib, ... }:
let
  rulesDir = ../../dotagents/rules;
  ruleNames = builtins.attrNames (
    lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".mdc" n) (builtins.readDir rulesDir)
  );

  parseRule =
    name:
    let
      path = rulesDir + "/${name}";
      parsed = frontmatterLib.importMarkdown path;
      stem = lib.removeSuffix ".mdc" name;
    in
    assert
      (parsed.frontmatter.alwaysApply or false) == true
      || throw "dotagents/rules/${name} must set alwaysApply: true (Cursor Authoring Format)";
    {
      name = stem;
      value = {
        inherit (parsed) frontmatter body;
        inherit path;
      };
    };

  discovered = builtins.listToAttrs (map parseRule ruleNames);
in
{
  options.dotagents.rules = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          frontmatter = lib.mkOption {
            type = lib.types.attrs;
            description = "Cursor .mdc frontmatter (alwaysApply, description, globs, …).";
          };
          body = lib.mkOption {
            type = lib.types.str;
            description = "Markdown body consumed by OpenCode/Claude Adapter Emit.";
          };
          path = lib.mkOption {
            type = lib.types.path;
            description = "Authored .mdc path for Cursor passthrough.";
          };
        };
      }
    );
    description = ''
      Common Model rules: each Cursor Authoring Format `.mdc` under
      `dotagents/rules/` with `alwaysApply`, keyed by filename stem, parsed
      by the Frontmatter Parser.
    '';
  };

  config.dotagents.rules = lib.mkDefault discovered;
}
