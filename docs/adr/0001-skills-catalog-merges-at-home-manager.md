# Skills catalog merges at home-manager

Adapters used to close solely over `flakeArgs.config.dotagents.skills` — the
catalog fixed at library flake-parts eval. Consumer-declared Skill Sources are
home-manager options, so the deployable catalog (library skills ∪ enabled
Skill Sources) merges at HM eval instead. Adapters call `mergeSkillCatalog`
with the library catalog plus `config.dotagents.skillSources` and abort on
duplicate skill ids.

Content Source (`dotagents.contentSources`) is stubbed beside Skill Source for
a future multi-root Authoring Format feature; it does not emit agents, rules,
or MCP in this cut.

## Considered Options

- **Flake-parts-only catalog**: every Skill Source would need a library input
  or module, so the lib would learn consumer URLs — rejected for URL-agnostic
  consumers.
- **HM-open merge (chosen)**: library packs stay URL-agnostic; consumers
  declare Skill Sources in home-manager; adapters assemble the catalog at
  eval time.
