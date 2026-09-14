# URL-agnostic skill-tree discovery and packing. Consumers pass a local `src`
# path (flake input, store path, or fixture); this module never names third-
# party skills remotes. Skill Source and upstream packagers share this path.
#
# Layouts:
#   flat      — immediate children of `root` that contain SKILL.md
#   recursive — any nested directory under `root` that contains SKILL.md
#               (directories without SKILL.md are skipped as skill keys;
#               walk continues into them so nest/<id>/SKILL.md is found)
#
# Packed form: $out/skills/<id>/SKILL.md (adapter skill layout).
{ lib }:
let
  inherit (builtins)
    attrNames
    concatMap
    map
    pathExists
    readDir
    ;

  listDirs =
    root:
    if !(pathExists root) then
      [ ]
    else
      attrNames (lib.filterAttrs (_: type: type == "directory") (readDir root));

  # Immediate child directories of `root` that contain a SKILL.md.
  skillDirs =
    root:
    if !(pathExists root) then
      [ ]
    else
      attrNames (
        lib.filterAttrs (name: type: type == "directory" && pathExists (root + "/${name}/SKILL.md")) (
          readDir root
        )
      );

  discoverFlat =
    root:
    map (name: {
      inherit name;
      path = root + "/${name}";
    }) (skillDirs root);

  # Depth-first walk: a directory with SKILL.md is a skill (basename = id);
  # otherwise recurse. Non-skill siblings (shared/, docs/) are not keys.
  discoverRecursive =
    root:
    let
      walk =
        dir:
        let
          entries = if pathExists dir then readDir dir else { };
        in
        concatMap (
          name:
          let
            type = entries.${name};
            path = dir + "/${name}";
          in
          if type != "directory" then
            [ ]
          else if pathExists (path + "/SKILL.md") then
            [ { inherit name path; } ]
          else
            walk path
        ) (attrNames entries);
    in
    walk root;

  discoverSkills =
    {
      root,
      layout ? "flat",
    }:
    if layout == "flat" then
      discoverFlat root
    else if layout == "recursive" then
      discoverRecursive root
    else
      throw "skillPackLib.discoverSkills: unknown layout '${layout}' (expected flat|recursive)";

  # Copy each discovered skill dir to $out/skills/<name>/.
  mkSkillsPackage =
    {
      pkgs,
      pname,
      skills,
    }:
    pkgs.runCommand pname { } ''
      mkdir -p "$out/skills"
      ${lib.concatMapStringsSep "\n" (s: ''
        cp -rL ${s.path} "$out/skills/${s.name}"
      '') skills}
    '';

  # Discover + pack from a content tree. `root` is relative to `src`
  # (Authoring Format default: "skills"); empty/null means `src` itself.
  packSkillRoot =
    {
      pkgs,
      pname,
      src,
      root ? "skills",
      layout ? "flat",
    }:
    let
      skillsRoot = if root == null || root == "" then src else src + "/${root}";
      skills = discoverSkills {
        root = skillsRoot;
        inherit layout;
      };
    in
    {
      inherit skills;
      names = map (s: s.name) skills;
      package = mkSkillsPackage {
        inherit pkgs pname skills;
      };
    };
in
{
  inherit
    listDirs
    skillDirs
    discoverSkills
    mkSkillsPackage
    packSkillRoot
    ;
}
