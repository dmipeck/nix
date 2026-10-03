# Pre-installs Thunderbird Conversations (Gmail conversation view) via
# enterprise policies when composed alongside the thunderbird homeModule.
# Addon: https://addons.thunderbird.net/en-US/thunderbird/addon/gmail-conversation-view/
#
# The ATN XPI is unsigned (experiment APIs; no META-INF) and the "latest.xpi"
# URL redirects, so we pin a store-local file:// install_url and allow weak
# signatures via Preferences.
{
  flake.homeModules.thunderbird-gmail-conversation-view =
    { pkgs, ... }:
    let
      conversationsXpi = pkgs.fetchurl {
        url = "https://addons.thunderbird.net/thunderbird/downloads/file/1051295/thunderbird_conversations-4.3.12-tb.xpi";
        hash = "sha256-Xdtk75dsI48nXQHXw+oRKPc3MM4roS6aCsZoPkQWLx4=";
        name = "gconversation@xulforum.org.xpi";
      };
    in
    {
      programs.thunderbird.policies = {
        ExtensionSettings."gconversation@xulforum.org" = {
          install_url = "file://${conversationsXpi}";
          installation_mode = "force_installed";
        };
        Preferences = {
          "xpinstall.signatures.required" = {
            Value = false;
            Status = "default";
          };
          "extensions.autoDisableScopes" = {
            Value = 0;
            Status = "default";
          };
        };
      };
    };
}
