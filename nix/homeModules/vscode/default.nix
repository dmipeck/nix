{
  self,
  inputs,
  lib,
  ...
}:

let
  baseProfileSettings = {
    userSettings = {
      "chat.disableAIFeatures" = true;
      "editor.formatOnSave" = true;
      "workbench.startupEditor" = "none";
      "workbench.browser.openLocalhostLinks" = false;
    };
  };
in

{
  options.flake.vscodeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "VS Code sub-module configuration functions, keyed by name.";
  };

  config.flake.homeModules.vscode =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      options.vscode.enable = lib.mkEnableOption "Enable Visual Studio Code module";

      options.vscode.profiles = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.modules = lib.mkOption {
              type = lib.types.listOf lib.types.raw;
              default = [ ];
              description = "List of vscode sub-module configurations to apply to this profile.";
            };
          }
        );
        default = { };
        description = "VS Code profiles, each with their own set of modules.";
      };

      config = {
        _module.args.vscodeModules = self.vscodeModules;

        vscode.enable = lib.mkDefault false;

        programs.vscode = lib.mkIf config.vscode.enable {
          enable = true;
          mutableExtensionsDir = false;
          profiles = lib.mapAttrs (
            _name: profileCfg: lib.mkMerge ([ baseProfileSettings ] ++ map (m: m pkgs) profileCfg.modules)
          ) config.vscode.profiles;
        };
      };
    };

  imports = [ inputs.home-manager.flakeModules.home-manager ];
}
