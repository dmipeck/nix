# Global rules — Cursor Authoring Format SoT (`rules/*.mdc`).
# Parsed into the Common Model via Frontmatter Parser; Adapter Emit:
# Cursor = passthrough .mdc, OpenCode/Claude = body only.
{ lib, frontmatterLib, ... }:
let
  rulesPath = ../../dotagents/rules/dotagents.mdc;
  parsed = frontmatterLib.importMarkdown rulesPath;
in
{
  options.dotagents.rules = lib.mkOption {
    type = lib.types.submodule {
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
    };
    description = ''
      Common Model rules entry: Cursor Authoring Format `.mdc` under
      `dotagents/rules/` with `alwaysApply`, parsed by the Frontmatter Parser.
    '';
  };

  config.dotagents.rules =
    assert
      (parsed.frontmatter.alwaysApply or false) == true
      || throw "dotagents/rules/dotagents.mdc must set alwaysApply: true (Cursor Authoring Format)";
    lib.mkDefault {
      inherit (parsed) frontmatter body;
      path = rulesPath;
    };
}
