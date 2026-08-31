{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no pkgs; reach into x86_64-linux via withSystem.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  skillsDir = ../../dotagents/skills;
  agentsDir = ../../dotagents/agents;
  commandsDir = ../../dotagents/commands;
  dotagentsDir = ../../dotagents;

  # Discover content by directory/file presence. Public name = directory
  # name (skills/agents) or filename minus .md (commands). No index files.
  skillNames = builtins.attrNames (
    lib.filterAttrs (_: v: v == "directory") (builtins.readDir skillsDir)
  );
  agentNames = builtins.attrNames (
    lib.filterAttrs (_: v: v == "directory") (builtins.readDir agentsDir)
  );
  commandNames = map (lib.removeSuffix ".md") (
    builtins.attrNames (lib.filterAttrs (_: v: v == "regular") (builtins.readDir commandsDir))
  );

  # Standardized skill package layout: $out/skills/<name>/SKILL.md
  skillPkg =
    name:
    pkgs.runCommand "dotagents-${name}" { } ''
      mkdir -p $out/skills
      cp -rL ${skillsDir}/${name} $out/skills/
    '';
  # Command package: $out IS the command file itself (matches existing scaffold pkg contract).
  commandPkg =
    name:
    pkgs.runCommand "dotagents-${name}" { } ''
      mkdir -p "$(dirname "$out")"
      cp ${commandsDir}/${name}.md "$out"
    '';

  # The whole dotagents content tree (skills/ + commands/ + agents/) in one
  # package; historically the golang/postgres skills and the commit/test
  # subagents were sliced out of it by the adapters via $out/skills/<name> /
  # $out/agents/<name>/agent.md. Kept for downstream consumers that want the
  # whole tree in a single store path.
  wholeTree = pkgs.runCommand "dotagents" { } ''
    mkdir -p $out
    cp -r ${dotagentsDir}/skills $out/skills
    cp -r ${dotagentsDir}/commands $out/commands
    cp -r ${dotagentsDir}/agents $out/agents
  '';

  # A parent option of `attrsOf` type cannot host nested option declarations
  # ("would be a parent of ..."), so the parent is a submodule (type name
  # "submodule", which allows nested options) with an `attrsOf` freeformType:
  # every key flows through the freeform type — auto-discovered local names
  # and the upstream modules' emitted names alike (there are no per-name
  # option declarations anymore; C3 moved those into per-module genAttrs
  # config under the freeform type).
  discovered =
    elemType:
    lib.types.submodule {
      freeformType = lib.types.attrsOf elemType;
    };

  # Auto-discovered values. Set as config with mkOptionDefault (priority 1500,
  # same as an option `default`) so a profile can still override them with a
  # plain (priority 100) definition. They cannot be an option `default`: the
  # module system drops a submodule parent's `default` entirely whenever any
  # higher-priority config definition targets the same option, so the
  # auto-discovered keys would never reach the freeform type.
in
{
  options.dotagents.skills = lib.mkOption {
    type = discovered lib.types.package;
    description = "AI skills. Local skills under dotagents/skills/ are discovered automatically; upstream skill collections add their own keys.";
  };
  options.dotagents.agents = lib.mkOption {
    type = discovered lib.types.path;
    description = "AI agent definitions (agent.md files), discovered automatically from dotagents/agents/.";
  };
  options.dotagents.commands = lib.mkOption {
    type = discovered lib.types.package;
    description = "AI tool command files, discovered automatically from dotagents/commands/.";
  };
  options.dotagents.localPackages = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    description = "Local AI content packages built from ../dotagents (skills/, commands/, agents/).";
  };

  config.dotagents.skills = lib.genAttrs skillNames (name: lib.mkOptionDefault (skillPkg name));
  config.dotagents.agents = lib.genAttrs agentNames (
    name: lib.mkOptionDefault (agentsDir + "/${name}/agent.md")
  );
  config.dotagents.commands = lib.genAttrs commandNames (name: lib.mkOptionDefault (commandPkg name));

  config.dotagents.localPackages = {
    whole-tree = wholeTree;
  };
}
