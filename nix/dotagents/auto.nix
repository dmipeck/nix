{
  config,
  lib,
  withSystem,
  ...
}:
let
  # flake-parts flake modules get no pkgs; reach into x86_64-linux via withSystem.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  skillsDir = ../../dotagents/skills;
  agentsDir = ../../dotagents/agents;
  dotagentsDir = ../../dotagents;

  # Discover content by directory presence. Public name = directory name.
  # No index files.
  skillNames = builtins.attrNames (
    lib.filterAttrs (_: v: v == "directory") (builtins.readDir skillsDir)
  );
  agentNames = builtins.attrNames (
    lib.filterAttrs (_: v: v == "directory") (builtins.readDir agentsDir)
  );

  # Standardized skill package layout: $out/skills/<name>/SKILL.md
  skillPkg =
    name:
    pkgs.runCommand "dotagents-${name}" { } ''
      mkdir -p $out/skills
      cp -rL ${skillsDir}/${name} $out/skills/
    '';

  # The whole dotagents content tree (skills/ + agents/) in one package;
  # historically the golang/postgres skills and the commit/test subagents were
  # sliced out of it by the adapters via $out/skills/<name> /
  # $out/agents/<name>/agent.md. Kept for downstream consumers that want the
  # whole tree in a single store path.
  wholeTree = pkgs.runCommand "dotagents" { } ''
    mkdir -p $out
    cp -r ${dotagentsDir}/skills $out/skills
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
    description = "AI skills. Local skills under dotagents/skills/ are discovered automatically; upstream skill collections add their own keys. User-invoked (slash-only) skills set `disable-model-invocation: true` in SKILL.md frontmatter — no separate commands layer.";
  };
  options.dotagents.agents = lib.mkOption {
    type = discovered lib.types.path;
    description = "AI agent definitions (agent.md files), discovered automatically from dotagents/agents/.";
  };
  options.dotagents.cheapSubagents = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "commit"
      "test"
      "format"
      "lint"
      "git"
      "github"
      "explore-git"
      "explore-github"
      "explore-nix"
      "cloudflare"
      "explore-cloudflare"
    ];
    description = ''
      Names of the cheap worker subagents whose model + variation each client
      adapter pulls from config.dotagents.models.<client>.subagent (see the
      `models` option for the per-client defaults). The source agent.md files
      stay model-neutral; each adapter injects its own `model:` line at render
      time.       Keep this list in sync with every adapter.
    '';
  };
  options.dotagents.models = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.primary = lib.mkOption {
          type = lib.types.submodule {
            options.model = lib.mkOption {
              type = lib.types.str;
            };
            options.variation = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
          };
        };
        options.subagent = lib.mkOption {
          type = lib.types.submodule {
            options.model = lib.mkOption {
              type = lib.types.str;
            };
            options.variation = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
          };
        };
      }
    );
    default = {
      claude = {
        primary = {
          model = "sonnet";
          variation = "high";
        };
        subagent = {
          model = "haiku";
          variation = "low";
        };
      };
      opencode = {
        primary = {
          model = "opencode-go/deepseek-v4-flash";
          variation = "high";
        };
        subagent = {
          model = "opencode-go/minimax-m3";
          variation = "none";
        };
      };
      cursor = {
        primary = {
          # Cursor session model is usually picked in the UI/CLI; inherit
          # keeps orchestrate on whatever the parent is running.
          model = "inherit";
          variation = null;
        };
        subagent = {
          # Fast Composer for cheap worker subagents.
          model = "composer-2.5";
          variation = null;
        };
      };
    };
    description = ''
      Per-client default model + variation for the primary agent and for the
      cheap worker subagents (config.dotagents.cheapSubagents). Each adapter
      maps model/variation onto its own dialect: claude uses settings.model +
      effortLevel for the primary and agent `model:`/`effort:` lines for cheap
      subagents; opencode uses settings.model + the default agent's `variant:`
      for the primary and `model:`/`variant:` lines in the rendered cheap
      subagent files; cursor writes `model:` (and optional `[effort=…]`
      brackets from variation) into `~/.cursor/agents/<name>.md`. A null
      variation means the adapter omits the variation field entirely.
    '';
  };

  options.dotagents.skillLayouts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.enum [
        "skill"
        "collection"
      ]
    );
    default = { };
    description = ''
      Per-skill layout. "skill" (default): the package exposes
      $out/skills/<name>/SKILL.md and adapters render $out/skills/<name>.
      "collection": the package is a whole bundle whose $out/skills/
      contains many constituent skills; adapters render the package root
      (claude: whole plugin) or skip it (opencode: no single-skill form).
    '';
  };
  options.dotagents.localPackages = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    description = "Local AI content packages built from ../dotagents (skills/, agents/).";
  };

  config.dotagents.skills = lib.genAttrs skillNames (name: lib.mkOptionDefault (skillPkg name));
  config.dotagents.agents = lib.genAttrs agentNames (
    name: lib.mkOptionDefault (agentsDir + "/${name}/agent.md")
  );

  config.dotagents.localPackages = {
    whole-tree = wholeTree;
  };
}
