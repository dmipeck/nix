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
      inherit (lib) types;

      # Drop null leaves, empty attrsets, and NixOS `_module` bookkeeping so
      # unset options are absent from the merge payload and do not overwrite
      # live CLI values.
      stripNulls =
        value:
        if builtins.isList value then
          map stripNulls value
        else if builtins.isAttrs value && !(lib.isDerivation value) then
          lib.filterAttrs (_: v: v != null && v != { }) (
            lib.mapAttrs (_: stripNulls) (builtins.removeAttrs value [ "_module" ])
          )
        else
          value;

      # Typed settings → JSON attrs for jq merge. freeformType accepts keys the
      # CLI adds later (e.g. changelog-only flags) without a module bump.
      settingsAttrs = stripNulls cfg.settings;

      settingsFile = jsonFormat.generate "cursor-cli-settings.json" settingsAttrs;
      seedFile = jsonFormat.generate "cursor-cli-seed.json" {
        version = 1;
        permissions = {
          allow = [ ];
          deny = [ ];
        };
      };

      # https://cursor.com/docs/cli/reference/configuration — plus a few fields
      # documented in the CLI changelog / update-cli-config skill that are not
      # yet on that page (`autoAcceptWebSearch`, `webFetchDomainAllowlist`,
      # `editor.defaultBehavior`, `sandbox.networkAllowlist`, `bedrock`,
      # `subagentModels`). CLI-owned caches (auth, model picker, privacy) are
      # intentionally omitted.
      settingsSubmodule = types.submodule {
        freeformType = jsonFormat.type;
        options = {
          channel = lib.mkOption {
            type = types.nullOr (
              types.either (types.enum [
                "prod"
                "lab"
                "static"
              ]) types.str
            );
            default = null;
            description = "Release channel used for CLI updates.";
          };

          maxMode = lib.mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Persisted preference for max mode in the model picker.";
          };

          notifications = lib.mkOption {
            type = types.nullOr types.bool;
            default = true;
            description = "Terminal notification when the agent finishes or needs input.";
          };

          hints = lib.mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Show CLI hints while the agent is working.";
          };

          rewind = lib.mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Enable /rewind to restore an earlier message in the session.";
          };

          suggestNextPrompt = lib.mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Suggest a follow-up prompt at the end of each turn.";
          };

          approvalMode = lib.mkOption {
            type = types.nullOr (
              types.enum [
                "allowlist"
                "auto-review"
                "unrestricted"
              ]
            );
            default = "auto-review";
            description = ''
              Tool approval mode: allowlist (default upstream), auto-review
              (classifier middle ground), or unrestricted (run everything).
            '';
          };

          autoAcceptWebSearch = lib.mkOption {
            type = types.nullOr types.bool;
            default = true;
            description = ''
              Auto-approve the built-in web search tool without a per-call
              prompt (CLI changelog; also toggleable under Permissions in
              /config).
            '';
          };

          webFetchDomainAllowlist = lib.mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = ''
              Domains the web fetch tool may access (e.g. docs.github.com,
              *.example.com, *).
            '';
            example = [
              "docs.github.com"
              "*.nixos.org"
            ];
          };

          editor = lib.mkOption {
            type = types.submodule {
              freeformType = jsonFormat.type;
              options = {
                vimMode = lib.mkOption {
                  type = types.nullOr types.bool;
                  default = true;
                  description = "Enable Vim keybindings in the CLI input.";
                };
                defaultBehavior = lib.mkOption {
                  type = types.nullOr (
                    types.enum [
                      "ide"
                      "agent"
                    ]
                  );
                  default = null;
                  description = "Default behavior mode for the CLI editor.";
                };
              };
            };
            default = { };
            description = "Editor preferences (`editor.vimMode`, …).";
          };

          permissions = lib.mkOption {
            type = types.nullOr (
              types.submodule {
                freeformType = jsonFormat.type;
                options = {
                  allow = lib.mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Permitted operations (Shell/Read/Write/WebFetch/Mcp tokens).";
                    example = [
                      "Shell(ls)"
                      "WebFetch(docs.github.com)"
                    ];
                  };
                  deny = lib.mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Forbidden operations.";
                    example = [
                      "Shell(rm)"
                      "Read(.env*)"
                    ];
                  };
                };
              }
            );
            default = null;
            description = ''
              Global permission allow/deny lists. Project-level overrides live
              in <project>/.cursor/cli.json (permissions only).
            '';
          };

          display = lib.mkOption {
            type = types.submodule {
              freeformType = jsonFormat.type;
              options = {
                showLineNumbers = lib.mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Show line numbers in rendered code blocks.";
                };
                showThinkingBlocks = lib.mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Render model thinking blocks when available.";
                };
                showStatusIndicators = lib.mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Enable terminal title status indicators.";
                };
                showStatusLineRunningTime = lib.mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Show elapsed running time in the status line.";
                };
              };
            };
            default = { };
            description = "Display / TUI rendering preferences.";
          };

          sandbox = lib.mkOption {
            type = types.submodule {
              freeformType = jsonFormat.type;
              options = {
                mode = lib.mkOption {
                  type = types.nullOr (
                    types.enum [
                      "disabled"
                      "enabled"
                    ]
                  );
                  default = null;
                  description = "Sandbox mode override.";
                };
                networkAccess = lib.mkOption {
                  type = types.nullOr (
                    types.enum [
                      "user_config_only"
                      "user_config_with_defaults"
                      "allow_all"
                    ]
                  );
                  default = null;
                  description = "Network access setting for sandbox mode.";
                };
                networkAllowlist = lib.mkOption {
                  type = types.nullOr (types.listOf types.str);
                  default = null;
                  description = "Domains the sandbox is allowed to reach.";
                };
              };
            };
            default = { };
            description = "Sandbox execution environment settings.";
          };

          network = lib.mkOption {
            type = types.submodule {
              freeformType = jsonFormat.type;
              options = {
                useHttp1ForAgent = lib.mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = ''
                    Use HTTP/1.1 instead of HTTP/2 for agent connections
                    (SSE; needed for some enterprise proxies).
                  '';
                };
              };
            };
            default = { };
            description = "Agent network / transport settings.";
          };

          attribution = lib.mkOption {
            type = types.submodule {
              freeformType = jsonFormat.type;
              options = {
                attributeCommitsToAgent = lib.mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = ''Add "Made with Cursor" trailer to Agent commits.'';
                };
                attributePRsToAgent = lib.mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = ''Add "Made with Cursor" footer to Agent PRs.'';
                };
              };
            };
            default = { };
            description = "How agent work is attributed in git commits/PRs.";
          };

          exploreSubagentModel = lib.mkOption {
            type = types.nullOr (
              types.enum [
                "default"
                "inherit"
              ]
            );
            default = null;
            description = ''
              Legacy Explore subagent model setting. Prefer
              `subagentModels.explore`; keep this in sync for older CLIs.
            '';
          };

          subagentModels = lib.mkOption {
            type = types.submodule {
              freeformType = jsonFormat.type;
              options = {
                explore = lib.mkOption {
                  type = types.nullOr (
                    types.either
                      (types.enum [
                        "default"
                        "inherit"
                        "disabled"
                      ])
                      (
                        types.submodule {
                          freeformType = jsonFormat.type;
                          options = {
                            modelId = lib.mkOption {
                              type = types.str;
                              description = "Pinned model id for the Explore subagent.";
                            };
                            parameters = lib.mkOption {
                              type = types.nullOr (
                                types.listOf (
                                  types.submodule {
                                    options = {
                                      id = lib.mkOption { type = types.str; };
                                      value = lib.mkOption { type = types.str; };
                                    };
                                  }
                                )
                              );
                              default = null;
                              description = "Optional per-model parameter overrides.";
                            };
                            maxMode = lib.mkOption {
                              type = types.nullOr types.bool;
                              default = null;
                              description = "Optional max-mode override for Explore.";
                            };
                          };
                        }
                      )
                  );
                  default = null;
                  description = ''
                    Explore subagent: Cursor default, inherit parent, disabled,
                    or a pinned { modelId, parameters?, maxMode? } object.
                  '';
                };
              };
            };
            default = { };
            description = "Per-subagent model settings.";
          };

          bedrock = lib.mkOption {
            type = types.submodule {
              freeformType = jsonFormat.type;
              options = {
                enabled = lib.mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Enable AWS Bedrock integration.";
                };
                mode = lib.mkOption {
                  type = types.nullOr (
                    types.enum [
                      "access-key"
                      "team-role"
                    ]
                  );
                  default = null;
                  description = "Bedrock auth mode.";
                };
                region = lib.mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "AWS region.";
                };
                testModel = lib.mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Model to use for Bedrock testing.";
                };
                teamRoleArn = lib.mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "IAM role ARN for team-role mode.";
                };
                teamExternalId = lib.mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "External ID for STS assume-role.";
                };
              };
            };
            default = { };
            description = "AWS Bedrock integration settings.";
          };
        };
      };
    in
    {
      options.programs.cursor-cli = {
        enable = lib.mkEnableOption "the Cursor CLI (cursor-agent)";

        package = lib.mkOption {
          type = types.package;
          default = pkgs.cursor-cli;
          description = "The cursor-cli package to install.";
        };

        settings = lib.mkOption {
          type = settingsSubmodule;
          default = { };
          example = {
            editor.vimMode = true;
            notifications = true;
            approvalMode = "auto-review";
            autoAcceptWebSearch = true;
            permissions = {
              allow = [ "Shell(ls)" ];
              deny = [ "Shell(rm)" ];
            };
            display.showLineNumbers = true;
            network.useHttp1ForAgent = true;
          };
          description = ''
            Typed preferences deep-merged into ~/.cursor/cli-config.json on
            activation (schema from
            https://cursor.com/docs/cli/reference/configuration). Null options
            are omitted so the live file's CLI-managed fields (model picker,
            auth, privacy/server caches, `version`) stay intact. Extra freeform
            keys are allowed for CLI fields not yet typed here.
          '';
        };

        agentAlias = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Whether to create a shell alias `agent` for `cursor-agent`.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Auth is interactive via `cursor-agent auth` (or CURSOR_API_KEY),
        # stored in the CLI's own config. This module installs the CLI and
        # merges `settings` into cli-config.json without owning the whole file.
        home.packages = [ cfg.package ];

        home.activation.cursorCliConfig = lib.mkIf (settingsAttrs != { }) (
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

        home.shellAliases = lib.mkIf cfg.agentAlias {
          agent = "cursor-agent";
        };
      };
    };
}
