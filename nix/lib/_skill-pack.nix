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

  # Top-level directories under `root` that are not skill keys (no SKILL.md).
  # Kept in the packed tree so relative shared/docs siblings still resolve.
  nonSkillSiblingDirs =
    root:
    if !(pathExists root) then
      [ ]
    else
      attrNames (
        lib.filterAttrs (
          name: type: type == "directory" && !(pathExists (root + "/${name}/SKILL.md"))
        ) (readDir root)
      );

  # Copy each discovered skill dir to $out/skills/<name>/, plus optional
  # non-skill sibling directories (shared/, docs/, …) under the same root.
  mkSkillsPackage =
    {
      pkgs,
      pname,
      skills,
      siblingDirs ? [ ],
    }:
    pkgs.runCommand pname { } ''
      mkdir -p "$out/skills"
      ${lib.concatMapStringsSep "\n" (s: ''
        cp -rL ${s.path} "$out/skills/${s.name}"
      '') skills}
      ${lib.concatMapStringsSep "\n" (s: ''
        cp -rL ${s.path} "$out/skills/${s.name}"
      '') siblingDirs}
    '';

  # Discover + pack from a content tree. `root` is relative to `src`
  # (Authoring Format default: "skills"); empty/null means `src` itself.
  # Skill keys are only directories with SKILL.md; non-skill top-level siblings
  # remain under $out/skills/<sibling>/ for relative references.
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
      siblingDirs = map (name: {
        inherit name;
        path = skillsRoot + "/${name}";
      }) (nonSkillSiblingDirs skillsRoot);
    in
    {
      inherit skills siblingDirs;
      names = map (s: s.name) skills;
      package = mkSkillsPackage {
        inherit pkgs pname skills siblingDirs;
      };
    };

  # Skill Source pack entry: same as packSkillRoot (URL-agnostic src/layout).
  # Named for the HM Skill Source seam; adapters merge packages in a later cut.
  packSkillSource = packSkillRoot;
in
{
  inherit
    listDirs
    skillDirs
    nonSkillSiblingDirs
    discoverSkills
    mkSkillsPackage
    packSkillRoot
    packSkillSource
    ;
}
