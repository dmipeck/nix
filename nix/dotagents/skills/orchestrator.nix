{ lib, config, ... }:
let
  # The orchestrator opencode agent definition lives in the whole-tree package
  # at $out/agents/orchestrator/agent.md, built from ../dotagents by
  # nix/dotagents/local.nix. Unlike the subagents it is a primary agent — the
  # opencode default — so it has no tools of its own and delegates every task
  # through `task`.
  local = config.dotagents.localPackages;
in
{
  options.dotagents.subagents.orchestrator = lib.mkOption {
    type = lib.types.path;
    description = "opencode agent definition for orchestrator (built from ../dotagents/agents/orchestrator/agent.md).";
  };

  config.dotagents.subagents.orchestrator = lib.mkDefault "${local.whole-tree}/agents/orchestrator/agent.md";
}
