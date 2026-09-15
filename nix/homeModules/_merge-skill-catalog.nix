# Merge enabled Skill Sources into the library skill catalog (HM-time).
# Leading `_` skips import-tree. Adapters call `mergeSkillCatalog`.
{ lib }:
let
  # Expand enabled Skill Sources into name → package (same shape as
  # `config.dotagents.skills`). Disabled sources contribute nothing
  # (`skillNames = []`, `package = null` from `_skill-sources.nix`).
  # Two enabled sources claiming the same skill id abort eval.
  skillsFromSources =
    skillSources:
    lib.foldlAttrs (
      acc: sourceName: src:
      lib.foldl (
        acc2: skillName:
        if acc2 ? ${skillName} then
          throw "dotagents.skillSources: duplicate skill '${skillName}' across enabled Skill Sources (conflict involving '${sourceName}')"
        else
          acc2 // { ${skillName} = src.package; }
      ) acc (src.skillNames or [ ])
    ) { } skillSources;

  # Library catalog ∪ enabled Skill Source skills. Duplicate attribute names
  # between the two sides abort evaluation (fail-closed; no silent override).
  # Skill Source keys inherit default layout "skill" — adapters' collection
  # filter (`skillLayouts.${name} or "skill"`) is unchanged.
  mergeSkillCatalog =
    librarySkills: skillSources:
    let
      fromSources = skillsFromSources skillSources;
      collisions = builtins.filter (n: librarySkills ? ${n}) (builtins.attrNames fromSources);
    in
    if collisions != [ ] then
      throw (
        "dotagents: duplicate skill attribute name(s) between library catalog and enabled Skill Sources: "
        + lib.concatStringsSep ", " (lib.sort builtins.lessThan collisions)
      )
    else
      librarySkills // fromSources;
in
{
  inherit skillsFromSources mergeSkillCatalog;
}
