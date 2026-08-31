{ lib, config, ... }:
let
  # The orchestrate opencode agent definition lives in the whole-tree package
  # at $out/agents/orchestrate/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix. Unlike the subagents it is a primary agent — the
  # opencode default — so it has no tools of its own and delegates every task
  # through `task`.
  local = config.dotagents.localPackages;

  # `outPath` is a string in Nix 2.34; `/. +` rebuilds it as a true path so
  # home-manager's `agents` option (lib.isPath) copies the file via `source`
  # instead of writing the path text as the agent definition.
  store = /. + builtins.unsafeDiscardStringContext local.whole-tree.outPath;
in
{
  options.dotagents.subagents.orchestrate = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for orchestrate (built from ../dotagents/agents/orchestrate/agent.md).";
  };

  config.dotagents.subagents.orchestrate = lib.mkDefault (store + "/agents/orchestrate/agent.md");
}
