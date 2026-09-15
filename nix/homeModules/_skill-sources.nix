# Skill Source + Content Source HM option fragment (URL-agnostic).
# Imported by homeModules.dotagents; leading `_` skips import-tree.
{ lib, pkgs }:
let
  skillPackLib = import ../lib/_skill-pack.nix { inherit lib; };

  skillSourceSubmodule = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether this Skill Source is packed. When false, `package` is null
          and `skillNames` is empty (adapters omit it).
        '';
      };
      src = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to an Authoring Format content tree (flake input, store path,
          or local path). Required when `enable` is true. The library never
          names a concrete skills remote.
        '';
      };
      root = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "skills";
        description = ''
          Directory under `src` that holds skills (Authoring Format default:
          "skills"). Empty or null means `src` itself is the skills root.
        '';
      };
      layout = lib.mkOption {
        type = lib.types.enum [
          "flat"
          "recursive"
        ];
        default = "flat";
        description = ''
          Discovery layout: `flat` = immediate children with SKILL.md;
          `recursive` = any nested directory with SKILL.md. Directories without
          SKILL.md are not skill keys; non-skill siblings remain in the packed
          tree.
        '';
      };
    };
  };

  # Pack enabled sources via skillPackLib; attach package + skillNames on the
  # option value (not separate declarations — avoids submodule name/config
  # recursion).
  packSources = lib.mapAttrs (
    name: cfg:
    if !cfg.enable then
      cfg
      // {
        package = null;
        skillNames = [ ];
      }
    else if cfg.src == null then
      throw "dotagents.skillSources.${name}: src is required when enable = true"
    else
      let
        packed = skillPackLib.packSkillSource {
          inherit pkgs;
          pname = "dotagents-skill-source-${name}";
          src = cfg.src;
          root = cfg.root;
          layout = cfg.layout;
        };
      in
      cfg
      // {
        package = packed.package;
        skillNames = packed.names;
      }
  );
in
{
  skillSources = lib.mkOption {
    type = lib.types.attrsOf skillSourceSubmodule;
    default = { };
    apply = packSources;
    description = ''
      Skill Sources — consumer-declared origins of skill packages. Each enabled
      entry is packed with the URL-agnostic skill pack helpers (`flat` /
      `recursive`). The merged value includes `package` and `skillNames`.
      Cursor / OpenCode / Claude adapters merge enabled packages into the
      library skill catalog via `_merge-skill-catalog.nix` (fail on duplicate).
    '';
  };

  contentSources = lib.mkOption {
    type = lib.types.attrs;
    default = { };
    description = ''
      Content Source stub — reserved for future consumer-declared Authoring
      Format roots (agents, skills, rules, mcp). Empty attrs only in this cut;
      setting keys does not emit agents, rules, or MCP config.
    '';
  };
}
