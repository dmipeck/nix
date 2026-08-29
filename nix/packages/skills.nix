{ ... }:

{
  # Packages the whole modules/skills/ collection as a single derivation
  # ($out/skills/<name>/SKILL.md per skill) — the same shape Claude Code
  # expects inside a plugin (see mkGrafanaSkillsPlugin in
  # modules/homeModules/claude.nix). Per-skill homeManager modules (e.g.
  # modules/homeModules/claudePlugins/git-workflow.nix) pluck their own
  # subdirectory out of this collection to build an individual plugin, so
  # this stays the single source of truth for skill content.
  flake.overlays.skills = final: _prev: {
    claude-skills = final.runCommand "claude-skills" { } ''
      mkdir -p $out/skills
      cp -rL ${../skills}/. $out/skills/
    '';
  };
}
