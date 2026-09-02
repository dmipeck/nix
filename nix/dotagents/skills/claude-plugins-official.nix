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

  # https://github.com/anthropics/claude-plugins-official — pinned as a
  # flake=false input; every plugin under plugins/ that carries a
  # skills/<name>/SKILL.md tree is auto-discovered at eval time. Plugin roots
  # have no SKILL.md themselves; each skill-bearing plugin is exposed as a
  # whole-bundle (collection) key plus one key per constituent skill. Layout:
  # plugins/<plugin>/skills/<name>/SKILL.md.
  claudePluginsOfficial = inputs.claude-plugins-official;

  dirs =
    root: builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir root));
  skillDirs =
    root:
    builtins.attrNames (
      lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (root + "/" + name + "/SKILL.md")
      ) (builtins.readDir root)
    );

  pluginsDir = claudePluginsOfficial + "/plugins";
  skillsOfPlugin =
    plugin:
    let
      skillsDir = pluginsDir + "/" + plugin + "/skills";
    in
    if builtins.pathExists skillsDir then skillDirs skillsDir else [ ];
  skillBearingPlugins = lib.filter (p: skillsOfPlugin p != [ ]) (dirs pluginsDir);

  # Copy an entire plugin dir to $out (its .claude-plugin + skills/ subtree).
  mkPlugin =
    plugin:
    pkgs.runCommand "dotagents-plugin-${plugin}" { } ''
      cp -rL ${claudePluginsOfficial}/plugins/${plugin} $out
    '';

  byPlugin = map (plugin: {
    inherit plugin;
    names = skillsOfPlugin plugin;
  }) skillBearingPlugins;

  skillKeys = builtins.listToAttrs (
    builtins.concatMap (
      entry: map (name: lib.nameValuePair name (mkPlugin entry.plugin)) entry.names
    ) byPlugin
  );

  # Whole-bundle key per plugin, unless the plugin name is already a
  # constituent skill (e.g. skill-creator's only skill is skill-creator).
  collectionKeys = builtins.listToAttrs (
    builtins.concatMap (
      entry:
      if builtins.elem entry.plugin entry.names then
        [ ]
      else
        [ (lib.nameValuePair entry.plugin (mkPlugin entry.plugin)) ]
    ) byPlugin
  );
in
{
  config.dotagents.skills = skillKeys // collectionKeys;

  # Whole-bundle keys: adapters render the package root (claude: whole plugin)
  # or skip it (opencode: no single-skill form).
  config.dotagents.skillLayouts = lib.genAttrs (builtins.attrNames collectionKeys) (_: "collection");
}
