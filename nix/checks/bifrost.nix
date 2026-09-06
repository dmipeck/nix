{ config, ... }@flakeArgs:
let
  mkBifrostSettings = flakeArgs.config.dotagents.bifrostSettings;
in
{
  # Static schema-validation checks for the three Bifrost provider profiles
  # from the brief (Claude Code passthrough, DeepSeek, OpenCode Zen): each
  # renders that profile's config.json through the exact same settings
  # builder the home-manager module uses (nix/dotagents/bifrostSettings.nix,
  # nix/homeModules/bifrost.nix), then validates it against Bifrost's own
  # vendored JSON Schema. No network / running server involved (`nix flake
  # check` is fully sandboxed), so this only proves each profile's generated
  # config.json is schema-valid — it does not exercise the gateway itself.
  perSystem =
    { pkgs, ... }:
    let
      # Same pin as nix/packages/bifrost.nix (maximhq/bifrost, `dev` branch
      # HEAD as of 2026-09-04); re-fetched here rather than threaded through
      # as a shared option, since it's a one-line literal pin, not logic.
      bifrostSrc = pkgs.fetchFromGitHub {
        owner = "maximhq";
        repo = "bifrost";
        rev = "03ab391865710462302bbcf52dca2f32682b91b5";
        hash = "sha256-pQMF/Tx24uRzLgjjobo9QqCUhXOX4qjFBZo8TFz1oJg=";
      };
      schemaFile = "${bifrostSrc}/transports/config.schema.json";
      settingsFormat = pkgs.formats.json { };

      # check-jsonschema (Python, in nixpkgs): a plain, well-maintained CLI
      # for validating a JSON document against a JSON Schema file, no custom
      # script needed — the schema declares draft 2019-09
      # ($schema: https://json-schema.org/draft/2019-09/schema), which it
      # supports.
      mkProfileCheck =
        name: settingsAttrs:
        let
          configFile = settingsFormat.generate "bifrost-config-${name}.json" settingsAttrs;
        in
        pkgs.runCommand "bifrost-config-${name}-check"
          {
            nativeBuildInputs = [ pkgs.check-jsonschema ];
          }
          ''
            check-jsonschema --schemafile ${schemaFile} ${configFile}
            touch $out
          '';
    in
    {
      checks.bifrost-config-claude-code-passthrough =
        mkProfileCheck "claude-code-passthrough"
          (mkBifrostSettings {
            claudeCodePassthrough = true;
          });

      checks.bifrost-config-deepseek = mkProfileCheck "deepseek" (mkBifrostSettings {
        deepseek = { };
      });

      checks.bifrost-config-opencode-zen = mkProfileCheck "opencode-zen" (mkBifrostSettings {
        opencodeZen = { };
      });
    };
}
