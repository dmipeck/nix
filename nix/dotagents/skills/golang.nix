{ lib, config, ... }:
let
  # The golang development skill set (api, cli, database, decoupling, layout,
  # migration, query, testing) plus the postgres schema-conventions skill live
  # in ../dotagents/skills/ and are packaged into the whole-tree package
  # (built by nix/dotagents/local.nix) at $out/skills/<name>. No dedicated
  # per-skill packages exist, so every golang/postgres skill maps to the same
  # tree package; the opencode/claude adapters slice out the skill directory
  # via $out/skills/<name>.
  wholeTree = config.dotagents.localPackages.whole-tree;
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
  options.dotagents.skills = lib.genAttrs golangSkills (
    name:
    lib.mkOption {
      type = lib.types.package;
      description = "opencode skill package for ${name} (local skill, built from ../dotagents/skills).";
    }
  );

  config.dotagents.skills = lib.genAttrs golangSkills (name: lib.mkDefault wholeTree);
}
