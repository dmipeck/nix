# Cursor agent stop / reply → local Gotify push (deterministic hooks, not model-called).
# stop is suppressed when afterAgentResponse already pushed for the same generation.
{
  sopsLib,
  ...
}:
{
  flake.homeModules.cursor-gotify =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.cursor-gotify;
      defaultPackage = pkgs.callPackage ../packages/cursor-gotify/_package.nix { };
      tokenPath = sopsLib.pathOrNull config cfg.sops "token";
      jsonFormat = pkgs.formats.json { };

      # User-hook entries Cursor resolves relative to ~/.cursor/
      stopHookCommand = "./hooks/cursor-gotify-stop.sh";
      afterAgentResponseHookCommand = "./hooks/cursor-gotify-after-agent-response.sh";

      stopHookScript = pkgs.writeShellScript "cursor-gotify-stop.sh" ''
        exec ${cfg.package}/bin/cursor-gotify hook-stop
      '';

      afterAgentResponseHookScript = pkgs.writeShellScript "cursor-gotify-after-agent-response.sh" ''
        exec ${cfg.package}/bin/cursor-gotify hook-after-agent-response
      '';

      # Seed / merge payload; jq merge preserves other hooks.
      hooksMergeFile = jsonFormat.generate "cursor-gotify-hooks-merge.json" ({
        version = 1;
        hooks = {
          stop = [
            {
              command = stopHookCommand;
            }
          ];
        }
        // lib.optionalAttrs cfg.afterAgentResponse.enable {
          afterAgentResponse = [
            {
              command = afterAgentResponseHookCommand;
            }
          ];
        };
      });
    in
    {
      options.programs.cursor-gotify = {
        enable = lib.mkEnableOption "Cursor agent lifecycle → Gotify notifications";

        package = lib.mkOption {
          type = lib.types.package;
          default = defaultPackage;
          description = "cursor-gotify package (Gotify push CLI + lifecycle hooks).";
        };

        url = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:80";
          description = ''
            Gotify server base URL (no trailing /message). Default assumes a
            local Gotify listening on port 80.
          '';
        };

        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Path to a file containing the Gotify application token. Ignored
            when sops-backed token is configured.
          '';
        };

        sops = lib.mkOption {
          type = sopsLib.mkType;
          default = { };
          description = ''
            Sops-backed Gotify application token. Gate with
            `programs.cursor-gotify.sops.enable`, then set
            `secrets.token.key`.
          '';
        };

        afterAgentResponse = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Wire Cursor `afterAgentResponse` → Gotify with truncated assistant
              text (heuristic context). Noisy: fires on every agent reply; does
              not mean the agent needs input. When enabled, successful reply
              pushes suppress the matching `stop` "Agent stopped" notification.
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = tokenPath != null || cfg.tokenFile != null;
            message = ''
              programs.cursor-gotify.enable requires a Gotify application token:
              set programs.cursor-gotify.sops.enable + secrets.token.key, or
              programs.cursor-gotify.tokenFile.
            '';
          }
        ];

        home.packages = [ cfg.package ];

        # Hook scripts Cursor invokes from ~/.cursor/hooks.json
        home.file.".cursor/hooks/cursor-gotify-stop.sh" = {
          source = stopHookScript;
          executable = true;
        };

        home.file.".cursor/hooks/cursor-gotify-after-agent-response.sh" =
          lib.mkIf cfg.afterAgentResponse.enable
            {
              source = afterAgentResponseHookScript;
              executable = true;
            };

        # Write GOTIFY_* env for the CLI; merge hooks into hooks.json
        # without wiping unrelated hooks (same idea as cursor-cli jq merge).
        home.activation.cursorGotify =
          lib.hm.dag.entryAfter ([ "linkGeneration" ] ++ lib.optional (tokenPath != null) "sops-nix")
            ''
                umask 077
                mkdir -p "$HOME/.config/cursor-gotify" "$HOME/.cursor"

                token_file=${lib.escapeShellArg (if tokenPath != null then tokenPath else cfg.tokenFile)}
                ${lib.optionalString (tokenPath != null) ''
                  systemctl="${config.systemd.user.systemctlPath}"
                  systemctlStatus="$($systemctl --user is-system-running 2>&1 || true)"
                  if [[ $systemctlStatus == 'running' || $systemctlStatus == 'degraded' ]]; then
                    $systemctl daemon-reload --user
                    $systemctl restart --user sops-nix
                  fi
                  unset systemctlStatus
                  for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
                    if [ -f "$token_file" ]; then
                      break
                    fi
                    ${pkgs.coreutils}/bin/sleep 0.1
                  done
                  if [ ! -f "$token_file" ]; then
                    echo "cursor-gotify: timed out waiting for sops secret at $token_file" >&2
                    exit 1
                  fi
                ''}
                if [ ! -f "$token_file" ]; then
                  echo "cursor-gotify: token file missing: $token_file" >&2
                  exit 1
                fi
                token="$(${pkgs.coreutils}/bin/tr -d '\n' < "$token_file")"
                {
                  echo "GOTIFY_URL=${lib.escapeShellArg cfg.url}"
                  echo "GOTIFY_TOKEN=$token"
                } > "$HOME/.config/cursor-gotify/env"
                ${pkgs.coreutils}/bin/chmod 600 "$HOME/.config/cursor-gotify/env"

                hooks="$HOME/.cursor/hooks.json"
                merge=${lib.escapeShellArg hooksMergeFile}
                if [ ! -f "$hooks" ]; then
                  ${pkgs.coreutils}/bin/cp "$merge" "$hooks"
                else
                  tmp="$(${pkgs.coreutils}/bin/mktemp)"
              ${pkgs.jq}/bin/jq -s '
                .[0] as $live | .[1] as $add
                | $live
                | .version = (.version // $add.version // 1)
                | .hooks = (.hooks // {})
                | .hooks.stop = (
                    ((.hooks.stop // []) + ($add.hooks.stop // []))
                    | unique_by(.command)
                  )
                | if ($add.hooks.afterAgentResponse // null) != null then
                    .hooks.afterAgentResponse = (
                      ((.hooks.afterAgentResponse // []) + ($add.hooks.afterAgentResponse // []))
                      | unique_by(.command)
                    )
                  else . end
              ' "$hooks" "$merge" > "$tmp"
                  ${pkgs.coreutils}/bin/mv "$tmp" "$hooks"
                fi
                ${pkgs.coreutils}/bin/chmod 600 "$hooks"
            '';
      };
    };
}
