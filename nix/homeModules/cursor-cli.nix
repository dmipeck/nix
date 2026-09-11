{
  flake.homeModules.cursor-cli =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.cursor-cli;
      jsonFormat = pkgs.formats.json { };
      # Preferences only — merged into the live CLI file so auth/model caches
      # the CLI writes itself are not clobbered on every home-manager switch.
      settingsFile = jsonFormat.generate "cursor-cli-settings.json" cfg.settings;
      seedFile = jsonFormat.generate "cursor-cli-seed.json" {
        version = 1;
        permissions = {
          allow = [ ];
          deny = [ ];
        };
      };
    in
    {
      options.programs.cursor-cli = {
        enable = lib.mkEnableOption "the Cursor CLI (cursor-agent)";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.cursor-cli;
          description = "The cursor-cli package to install.";
        };

        settings = lib.mkOption {
          type = jsonFormat.type;
          default = {
            editor.vimMode = true;
            notifications = true;
            approvalMode = "auto-review";
            autoAcceptWebSearch = true;
          };
          example = {
            editor.vimMode = true;
            notifications = true;
            approvalMode = "auto-review";
            autoAcceptWebSearch = true;
          };
          description = ''
            Preferences deep-merged into ~/.cursor/cli-config.json on
            activation. Declared keys win; CLI-managed fields (model, auth,
            privacy/server caches) are left alone. See
            https://cursor.com/docs/cli/reference/configuration and the
            CLI changelog for `autoAcceptWebSearch` / `approvalMode`.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # Auth is interactive via `cursor-agent auth` (or CURSOR_API_KEY),
        # stored in the CLI's own config. This module installs the CLI and
        # merges `settings` into cli-config.json without owning the whole file.
        home.packages = [ cfg.package ];

        home.activation.cursorCliConfig = lib.mkIf (cfg.settings != { }) (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            configDir="$HOME/.cursor"
            configPath="$configDir/cli-config.json"
            desired="${settingsFile}"
            seed="${seedFile}"
            jq="${pkgs.jq}/bin/jq"

            run mkdir -p "$configDir"
            umask 077

            if [[ -f "$configPath" ]]; then
              # Resolve symlinks to a real file before merging (HM may have
              # linked a store path in earlier experiments).
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
          ''
        );
      };
    };
}
