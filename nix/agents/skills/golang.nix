{ lib, inputs, ... }:
let
  # The golang development skill set (api, cli, database, decoupling, layout,
  # migration, query, testing) plus the postgres schema-conventions skill ship
  # inside the dmipeck/agents whole-tree `agents` package at $out/skills/<name>.
  # No dedicated per-skill packages exist, so every golang/postgres skill maps
  # to the same tree package; the opencode/claude adapters slice out the skill
  # directory via $out/skills/<name>.
  agentsPkg = inputs.agents.packages.x86_64-linux.agents;
  golangSkills = [
    "golang-api"
    "golang-cli"
    "golang-database"
    "golang-decoupling"
    "golang-layout"
    "golang-migration"
    "golang-query"
    "golang-testing"
    "postgres"
  ];
in
{
  options.agents.skills = lib.genAttrs golangSkills (
    name:
    lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for ${name} (local skill, built by dmipeck/agents).";
    }
  );

  config.agents.skills = lib.genAttrs golangSkills (name: lib.mkDefault agentsPkg);
}
