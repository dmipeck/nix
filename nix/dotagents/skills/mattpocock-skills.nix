{
  lib,
  withSystem,
  inputs,
  skillPackLib,
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

  inherit (skillPackLib) listDirs skillDirs;

  # Discover every skill under every category directory.
  categories = listDirs (mattpocockSkillsSrc + "/skills");
  discovered = builtins.concatMap (
    category:
    map (name: { inherit category name; }) (skillDirs (mattpocockSkillsSrc + "/skills/" + category))
  ) categories;

  # Copy an upstream sub-directory into $out/skills/<name>, producing the
  # shared $out/skills/<name>/SKILL.md layout both Claude plugins and opencode
  # read. User-invoked skills already carry `disable-model-invocation: true`
  # in their SKILL.md frontmatter; adapters pass that through as-is (no
  # separate auto-generated slash-command layer).
  #
  # setup-matt-pocock-skills is patched so it auto-discovers the local
  # `gitlab-tracker` skill (dotagents/skills/gitlab-tracker) and
  # prefers that template when configuring a GitLab repo.
  setupGitlabTrackerPatch = ./patches/setup-matt-pocock-skills-gitlab-tracker.patch;

  mkSkill =
    { name, category }:
    pkgs.runCommand "dotagents-${name}"
      {
        nativeBuildInputs = lib.optionals (name == "setup-matt-pocock-skills") [ pkgs.patch ];
      }
      ''
        mkdir -p $out/skills/${name}
        cp -rL ${mattpocockSkillsSrc}/skills/${category}/${name}/. $out/skills/${name}/
        ${lib.optionalString (name == "setup-matt-pocock-skills") ''
          patch -p1 -d $out/skills/${name} < ${setupGitlabTrackerPatch}
        ''}
      '';
in
{
  config.dotagents.skills = builtins.listToAttrs (
    map (s: lib.nameValuePair s.name (mkSkill s)) discovered
  );
}
