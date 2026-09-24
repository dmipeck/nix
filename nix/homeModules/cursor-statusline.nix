# Cursor CLI custom status line (separate from the cursor adapter module).
# Installs the wrapped script and merges `statusLine` into cli-config.json
# without wiping CLI-owned fields (same jq deep-merge idea as cursor-cli).
{
  flake.homeModules.cursor-statusline =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.cursor-statusline;
      defaultPackage = pkgs.callPackage ../packages/cursor-statusline/_package.nix { };
      jsonFormat = pkgs.formats.json { };
      inherit (lib) types;

      statusLineAttrs = {
        type = "command";
        command = "${cfg.package}/bin/cursor-statusline";
        padding = cfg.padding;
      }
      // lib.optionalAttrs (cfg.updateIntervalMs != null) {
        updateIntervalMs = cfg.updateIntervalMs;
      }
      // lib.optionalAttrs (cfg.timeoutMs != null) {
        timeoutMs = cfg.timeoutMs;
      };

      mergeFile = jsonFormat.generate "cursor-statusline-merge.json" {
        statusLine = statusLineAttrs;
      };

      seedFile = jsonFormat.generate "cursor-statusline-seed.json" {
        version = 1;
        permissions = {
          allow = [ ];
          deny = [ ];
        };
      };
    in
    {
      options.programs.cursor-statusline = {
        enable = lib.mkEnableOption "Cursor CLI custom status line";

        package = lib.mkOption {
          type = types.package;
          default = defaultPackage;
          description = "cursor-statusline package (StatusLinePayload → ANSI status row).";
        };

        padding = lib.mkOption {
          type = types.int;
          default = 2;
          description = "Horizontal inset (characters) for the status line container.";
        };

        updateIntervalMs = lib.mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          description = ''
            Minimum interval between status-line invocations (CLI clamps to
            >= 300ms). Null omits the field so the CLI default applies.
          '';
        };

        timeoutMs = lib.mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          description = ''
            Maximum time the command may run before it is killed. Null omits
            the field so the CLI default applies.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ cfg.package ];

        # Merge after cursor-cli when present so our statusLine wins over any
        # freeform settings; still safe if cursor-cli is not imported.
        home.activation.cursorStatusline =
          let
            after = [
              "writeBoundary"
            ]
            ++ lib.optional (config.home.activation ? cursorCliConfig) "cursorCliConfig";
          in
          lib.hm.dag.entryAfter after ''
            configDir="$HOME/.cursor"
            configPath="$configDir/cli-config.json"
            desired=${lib.escapeShellArg mergeFile}
            seed=${lib.escapeShellArg seedFile}
            jq=${lib.escapeShellArg "${pkgs.jq}/bin/jq"}

            run mkdir -p "$configDir"
            umask 077

            if [[ -f "$configPath" ]]; then
              if [[ -L "$configPath" ]]; then
                storePath="$(readlink -f "$configPath")"
                run rm -f "$configPath"
                run install -m600 "$storePath" "$configPath"
              fi
              "$jq" -s '.[0] * .[1]' "$configPath" "$desired" > "$configPath.tmp"
              run mv "$configPath.tmp" "$configPath"
              run chmod 600 "$configPath"
            else
              "$jq" -s '.[0] * .[1]' "$seed" "$desired" > "$configPath"
              run chmod 600 "$configPath"
            fi
          '';
      };
    };
}
