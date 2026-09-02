{
  lib,
  withSystem,
  inputs,
  ...
}:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The skill
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # https://github.com/mattpocock/skills — pinned as a flake=false input so the
  # source path is readable at eval time and skill names are auto-discovered
  # instead of hard-coded. Upstream layout: skills/<category>/<name>/SKILL.md.
  mattpocockSkillsSrc = inputs.mattpocock-skills;

  # Directories under `root` that contain a SKILL.md regular file.
  skillDirs =
    root:
    builtins.attrNames (
      lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (root + "/" + name + "/SKILL.md")
      ) (builtins.readDir root)
    );

  # Discover every skill under every category directory.
  categories = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir (mattpocockSkillsSrc + "/skills"))
  );
  discovered = builtins.concatMap (
    category:
    map (name: { inherit category name; }) (skillDirs (mattpocockSkillsSrc + "/skills/" + category))
  ) categories;

  # User-invoked skills carry `disable-model-invocation: true` in their SKILL.md
  # frontmatter; those get an auto-generated slash-command via
  # config.dotagents.skillCommands.
  hasInvocationFlag =
    { name, category }:
    builtins.match ".*disable-model-invocation:[ \t]*true.*" (
      builtins.readFile (mattpocockSkillsSrc + "/skills/" + category + "/" + name + "/SKILL.md")
    ) != null;

  userInvokedNames = map (s: s.name) (lib.filter hasInvocationFlag discovered);

  # Copy an upstream sub-directory into $out/skills/<name>, producing the
  # shared $out/skills/<name>/SKILL.md layout both Claude plugins and opencode
  # read.
  mkSkill =
    { name, category }:
    pkgs.runCommand "dotagents-${name}" { } ''
      mkdir -p $out/skills/${name}
      cp -rL ${mattpocockSkillsSrc}/skills/${category}/${name}/. $out/skills/${name}/
    '';
in
{
  config.dotagents.skills = builtins.listToAttrs (
    map (s: lib.nameValuePair s.name (mkSkill s)) discovered
  );
  config.dotagents.skillCommands = userInvokedNames;
}
