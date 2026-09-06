{ lib, ... }:
{
  # A pure function building a Bifrost `config.json` settings attrset from a
  # small profile spec, shared by `flake.homeModules.bifrost`
  # (nix/homeModules/bifrost.nix, deriving the spec from its own option
  # values) and the `bifrost-config-*` static schema-validation checks
  # (nix/checks/bifrost.nix, calling it directly with a hand-written spec per
  # profile) — so the two never drift out of sync. Exposed as a
  # `dotagents.*`-style option (like `dotagents.mcpServers`) rather than a
  # plain library file, since every file under nix/ is auto-imported as a
  # flake-parts module by import-tree: a bare "return a function" file would
  # be rejected as an unrecognized flake-parts option.
  options.dotagents.bifrostSettings = lib.mkOption {
    type = lib.types.anything;
    description = ''
      Function `{ claudeCodePassthrough ? false, deepseek ? null, opencodeZen ? null, extraSettings ? {} }: settingsAttrs`
      building the Bifrost config.json settings attrset for a provider
      profile. `deepseek`/`opencodeZen`, when non-null, are `{
      useAnthropicEndpoints ? false }`/`{}` respectively; `extraSettings` is
      recursively merged in last (escape hatch, takes precedence on
      conflicts).
    '';
  };

  config.dotagents.bifrostSettings =
    {
      claudeCodePassthrough ? false,
      deepseek ? null,
      opencodeZen ? null,
      extraSettings ? { },
    }:
    let
      # client.allow_direct_keys: the exact config.json field (confirmed by
      # grepping the vendored transports/config.schema.json, under the
      # top-level "client" object) for Bifrost's "Allow Direct API Keys"
      # toggle — lets a caller bypass the registered key pool by sending
      # x-bf-direct-key: true plus the provider's raw key in an
      # Authorization/x-api-key/x-goog-api-key header. This is the mechanism
      # the Claude Code passthrough profile relies on (see
      # nix/homeModules/bifrost.nix's claudeCodePassthrough option for the
      # full picture and its caveats).
      clientSettings = lib.optionalAttrs claudeCodePassthrough {
        client.allow_direct_keys = true;
      };

      deepseekSettings = lib.optionalAttrs (deepseek != null) {
        providers.deepseek.keys = [
          (
            {
              name = "deepseek";
              weight = 1.0;
              value = "env.DEEPSEEK_API_KEY";
            }
            // lib.optionalAttrs (deepseek.useAnthropicEndpoints or false) {
              use_anthropic_endpoints = true;
            }
          )
        ];
      };

      opencodeZenSettings = lib.optionalAttrs (opencodeZen != null) {
        providers."opencode-zen".keys = [
          {
            name = "opencode-zen";
            weight = 1.0;
            value = "env.OPENCODE_API_KEY";
          }
        ];
      };
    in
    lib.recursiveUpdate (lib.recursiveUpdate (lib.recursiveUpdate clientSettings deepseekSettings) opencodeZenSettings) extraSettings;
}
