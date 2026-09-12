# Shared sops option contract for modules (import-tree skips `_*.nix`):
#   <module>.sops.enable
#   <module>.sops.secrets.<program-key-name>.key = "<sops-key-name>"
#   <module>.sops.secrets.<program-key-name>.keyFile = ...  # optional path override
{ lib }:
let
  secretType = lib.types.submodule {
    options = {
      key = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Name of the sops-nix secret. When set and keyFile is null, the
          decrypted path is config.sops.secrets.''${key}.path.
        '';
      };
      keyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional path to the secret file. When set, overrides the path
          derived from key (use for an already-available decrypted file).
        '';
      };
    };
  };

  mkType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to wire sops-backed secrets for this module.";
      };
      secrets = lib.mkOption {
        type = lib.types.attrsOf secretType;
        default = { };
        description = ''
          Named secrets for this module. Keys are program-local names
          (e.g. accessToken, apiKey); each entry points at a sops-nix
          secret name and/or an explicit keyFile path.
        '';
      };
    };
  };

  secretConfigured =
    sopsCfg: name:
    sopsCfg.enable
    && sopsCfg.secrets ? ${name}
    && (sopsCfg.secrets.${name}.key != null || sopsCfg.secrets.${name}.keyFile != null);

  resolvePath =
    config: secret:
    if secret.keyFile != null then
      secret.keyFile
    else if secret.key != null then
      config.sops.secrets.${secret.key}.path
    else
      null;

  # Path for a named secret when sops.enable and the entry is configured;
  # null otherwise.
  pathOrNull =
    config: sopsCfg: name:
    if secretConfigured sopsCfg name then resolvePath config sopsCfg.secrets.${name} else null;
in
{
  inherit
    secretType
    mkType
    secretConfigured
    resolvePath
    pathOrNull
    ;
}
