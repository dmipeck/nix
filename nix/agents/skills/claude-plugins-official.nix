{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem. The skill
  # packages are derivations; evaluation stays lazy until a consumer forces one.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  claudePluginsOfficial = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "a488bee3a01ce38125d372b560c9c7fa25d0deb6";
    hash = "sha256-8Ri0iSyAmayOEk/Jx7C9mGBQVeMTJE8hOVVMoU5B1Ps=";
  };
  # Build a derivation whose $out/ holds a full claude-plugins-official plugin
  # (with $out/skills/ subdirectory), satisfying both Claude's plugin layout
  # and opencode's skills/<name> lookup.
  mkPlugin =
    name:
    pkgs.runCommand "agents-plugin-${name}" { } ''
      cp -rL ${claudePluginsOfficial}/plugins/${name} $out
    '';
in
{
  options.agents.skills = {
    "mcp-server-dev" = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for mcp-server-dev ($out/skills/mcp-server-dev/SKILL.md).";
    };
    "skill-creator" = lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for skill-creator ($out/skills/skill-creator/SKILL.md).";
    };
  };

  config.agents.skills = {
    "mcp-server-dev" = lib.mkDefault (mkPlugin "mcp-server-dev");
    "skill-creator" = lib.mkDefault (mkPlugin "skill-creator");
  };
}
