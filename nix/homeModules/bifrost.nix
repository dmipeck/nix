{ inputs, ... }@flakeArgs:
let
  # bifrost-http now comes from the official maximhq/bifrost flake (flake
  # input `bifrost`, tracking main) rather than a locally-vendored custom
  # build (nix/packages/bifrost.nix, deleted). Only x86_64-linux is
  # supported by this repo (nix/devShells/default.nix), which is also a
  # supported system upstream. The option remains overridable via
  # services.bifrost.package.
  bifrostHttpPackage = inputs.bifrost.packages.x86_64-linux.bifrost-http;
  mkBifrostSettings = flakeArgs.config.dotagents.bifrostSettings;
in
{
  # Home-manager config layer for Bifrost (https://github.com/maximhq/bifrost),
  # an LLM gateway: exposes its config.json as nix options and runs it as a
  # systemd user service. See nix/dotagents/bifrostSettings.nix for the
  # config.json settings-builder shared with the bifrost-config-* checks
  # (nix/checks/bifrost.nix).
  flake.homeModules.bifrost =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.services.bifrost;
      settingsFormat = pkgs.formats.json { };

      # Typed provider options (below) plus the free-form `settings` escape
      # hatch are merged through the one shared builder (mkBifrostSettings,
      # nix/dotagents/bifrostSettings.nix) also used by the
      # bifrost-config-* checks, so the module and the checks can't drift.
      generatedSettings = mkBifrostSettings {
        claudeCodePassthrough = cfg.claudeCodePassthrough.enable;
        deepseek =
          if cfg.providers.deepseek.enable then
            { useAnthropicEndpoints = cfg.providers.deepseek.useAnthropicEndpoints; }
          else
            null;
        opencodeZen = if cfg.providers.opencodeZen.enable then { } else null;
        extraSettings = if cfg.settings == null then { } else cfg.settings;
      };
      configFile =
        if generatedSettings == { } then
          null
        else
          settingsFormat.generate "bifrost-config.json" generatedSettings;

      # Env vars whose value must land in the service's process environment
      # (Bifrost's config.json `value: "env.VAR_NAME"` reads the literal env
      # var, not a file), sourced from sops-nix secrets. Provider
      # convenience options (below) contribute their own entry automatically
      # so a profile only has to set `apiKeySopsKey` once.
      effectiveSecretEnv =
        cfg.secretEnv
        //
          lib.optionalAttrs (cfg.providers.deepseek.enable && cfg.providers.deepseek.apiKeySopsKey != null)
            {
              DEEPSEEK_API_KEY = cfg.providers.deepseek.apiKeySopsKey;
            }
        //
          lib.optionalAttrs
            (cfg.providers.opencodeZen.enable && cfg.providers.opencodeZen.apiKeySopsKey != null)
            {
              OPENCODE_API_KEY = cfg.providers.opencodeZen.apiKeySopsKey;
            };

      # A bash wrapper (mirrors nix/homeModules/gitlab-cli.nix's wrapper
      # pattern): reads each sops-decrypted secret file into its env var at
      # startup — the secret value itself never lands in the Nix store, only
      # the file path — installs config.json (if any settings were
      # generated), then execs the real binary. Systemd user services have
      # no NixOS-style StateDirectory/DynamicUser/preStart, so the state dir
      # and config file are handled here instead.
      startScript = pkgs.writeShellScript "bifrost-http-start" ''
        set -euo pipefail
        mkdir -p ${lib.escapeShellArg cfg.stateDir}
        ${lib.optionalString (
          configFile != null
        ) "install -Dm600 ${configFile} ${lib.escapeShellArg "${cfg.stateDir}/config.json"}"}
        ${lib.concatStrings (
          lib.mapAttrsToList (varName: sopsKey: ''
            export ${varName}="$(<${config.sops.secrets.${sopsKey}.path})"
          '') effectiveSecretEnv
        )}
        exec ${lib.getExe cfg.package} \
          -host ${lib.escapeShellArg cfg.host} \
          -port ${lib.escapeShellArg (toString cfg.port)} \
          -app-dir ${lib.escapeShellArg cfg.stateDir} \
          -log-level ${lib.escapeShellArg cfg.logLevel} \
          -log-style ${lib.escapeShellArg cfg.logStyle} \
          ${lib.concatMapStringsSep " " lib.escapeShellArg cfg.extraArgs}
      '';
    in
    {
      options.services.bifrost = {
        enable = lib.mkEnableOption "the Bifrost LLM gateway (bifrost-http) as a systemd user service";

        package = lib.mkOption {
          type = lib.types.package;
          default = bifrostHttpPackage;
          description = "The bifrost-http package to run (official maximhq/bifrost flake, packages.<system>.bifrost-http).";
        };

        stateDir = lib.mkOption {
          type = lib.types.str;
          default = "${config.xdg.stateHome}/bifrost";
          description = "Application data directory (contains config.json and logs).";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "The host address which the Bifrost HTTP server listens to.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 8080;
          description = "Which port the Bifrost HTTP server listens to.";
        };

        logLevel = lib.mkOption {
          type = lib.types.enum [
            "debug"
            "info"
            "warn"
            "error"
          ];
          default = "info";
          description = "Logger level.";
        };

        logStyle = lib.mkOption {
          type = lib.types.enum [
            "json"
            "pretty"
          ];
          default = "json";
          description = "Logger output style.";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra CLI arguments passed to bifrost-http.";
        };

        settings = lib.mkOption {
          type = lib.types.nullOr settingsFormat.type;
          default = null;
          description = ''
            Free-form content merged into `config.json`, on top of whatever
            the typed options below (claudeCodePassthrough, providers.*)
            generate — this always wins on conflicts. Use it for anything
            Bifrost supports that doesn't have a dedicated option here. Left
            entirely null with no typed option enabled either, no config.json
            is written and Bifrost bootstraps from its own defaults/env.
          '';
        };

        environment = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            Plain (non-secret) extra environment variables for the service,
            e.g. BIFROST_ENV_LABEL. For a provider API key, use `secretEnv`
            (or a provider's `apiKeySopsKey`) instead — never inline a real
            secret value here.
          '';
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Environment file passed to the systemd user unit's
            EnvironmentFile= (already-decrypted KEY=value pairs, e.g. from a
            sops-nix template). Useful when a secret's value is already
            available as a whole env file rather than one sops secret per
            variable (see `secretEnv` for that case).
          '';
        };

        secretEnv = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            Maps an env var name Bifrost's config.json expects (via its
            `"value": "env.VAR_NAME"` key indirection, e.g. DEEPSEEK_API_KEY)
            to the name of a sops-nix secret holding that key's actual
            value. Bifrost needs the literal value in the process
            environment (not a file path), so — mirroring
            nix/homeModules/gitlab-cli.nix's wrapper pattern — the service's
            start script reads each sops-decrypted secret file into its env
            var at startup; the value itself never lands in the Nix store.
          '';
        };

        # Claude Code has no native subscription/OAuth support in Bifrost's
        # Anthropic provider (only a plain ANTHROPIC_API_KEY) — confirmed
        # open, unimplemented upstream issue maximhq/bifrost#1390. This
        # profile instead wires an UNOFFICIAL passthrough workaround
        # (documented in a comment on that issue by msotnikov, 2026-07-15,
        # unverified by upstream maintainers or other users): it does not
        # touch config.json's provider-keys at all. Enabling it does two
        # things: (1) sets client.allow_direct_keys = true in config.json,
        # Bifrost's toggle (confirmed by grepping
        # transports/config.schema.json) letting a caller bypass the
        # registered key pool by sending x-bf-direct-key: true plus the
        # provider's raw API key in an Authorization/x-api-key/x-goog-api-key
        # header; (2) exposes ANTHROPIC_BASE_URL/ANTHROPIC_CUSTOM_HEADERS via
        # home.sessionVariables, pointing Claude Code itself at this gateway.
        # Claude Code's own existing Anthropic auth (its native subscription
        # OAuth bearer token) then passes straight through Bifrost to
        # Anthropic unmodified — Bifrost never sees or needs the token.
        #
        # home.sessionVariables (not a claude.nix edit) is the seam: that
        # module manages Claude Code's own settings.json/plugins/agents, not
        # arbitrary process environment, so wiring these two env vars here
        # keeps this module self-contained and claude.nix untouched.
        claudeCodePassthrough.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable the unofficial Claude Code subscription passthrough
            workaround (see the option group's own comment in
            nix/homeModules/bifrost.nix for the full mechanism and its
            caveats — this is NOT real Claude Code support inside Bifrost,
            just a client-side header relay around a missing upstream
            feature, maximhq/bifrost#1390).
          '';
        };

        providers.deepseek = {
          enable = lib.mkEnableOption "the DeepSeek provider in config.json";
          apiKeySopsKey = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Name of the sops-nix secret holding the DeepSeek API key.
              Wired into the DEEPSEEK_API_KEY env var Bifrost's
              `env.DEEPSEEK_API_KEY` config.json key value reads (see
              `secretEnv`); leave null to supply DEEPSEEK_API_KEY some other
              way (e.g. `environment`/`environmentFile`).
            '';
          };
          useAnthropicEndpoints = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Route chat completions/responses through DeepSeek's Anthropic-compatible endpoints.";
          };
        };

        providers.opencodeZen = {
          enable = lib.mkEnableOption "the OpenCode Zen provider (opencode-zen) in config.json";
          apiKeySopsKey = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Name of the sops-nix secret holding the OpenCode Zen API key.
              Wired into the OPENCODE_API_KEY env var Bifrost's
              `env.OPENCODE_API_KEY` config.json key value reads (see
              `secretEnv`); leave null to supply OPENCODE_API_KEY some other
              way.
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.user.services.bifrost-http = {
          Unit = {
            Description = "Bifrost AI Gateway (bifrost-http)";
            After = [ "network.target" ];
          };
          Service = {
            ExecStart = "${startScript}";
            Environment = lib.mapAttrsToList (n: v: "${n}=${v}") cfg.environment;
            EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
            Restart = "on-failure";
          };
          Install.WantedBy = [ "default.target" ];
        };

        home.sessionVariables = lib.mkIf cfg.claudeCodePassthrough.enable {
          ANTHROPIC_BASE_URL = "http://127.0.0.1:${toString cfg.port}/anthropic";
          ANTHROPIC_CUSTOM_HEADERS = "x-bf-direct-key: true";
        };
      };
    };
}
