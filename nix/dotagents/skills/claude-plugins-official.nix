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
    pkgs.runCommand "dotagents-plugin-${name}" { } ''
      cp -rL ${claudePluginsOfficial}/plugins/${name} $out
    '';
in
{
  # Each mcp-server-dev plugin skill is exposed by its own name, and the
  # plugin key itself (mcp-server-dev) is exposed as a whole bundle marked
  # layout "collection": its package $out/skills/ contains the constituent
  # skills, so adapters render the package root (claude: whole plugin) or
  # skip it (opencode: no single-skill form). skill-creator's plugin dir
  # carries skills/skill-creator, so its exposed name is the plugin key
  # itself, a plain "skill".
  config.dotagents.skills =
    lib.genAttrs [
      "build-mcp-app"
      "build-mcp-server"
      "build-mcpb"
      "mcp-server-dev"
    ] (_: mkPlugin "mcp-server-dev")
    // lib.genAttrs [ "skill-creator" ] (_: mkPlugin "skill-creator");

  config.dotagents.skillLayouts."mcp-server-dev" = "collection";
}
