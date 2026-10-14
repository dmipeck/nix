# Pre-installs Thunderbird Conversations (Gmail conversation view) via
# enterprise policies when composed alongside the thunderbird homeModule.
# Addon: https://addons.thunderbird.net/en-US/thunderbird/addon/gmail-conversation-view/
#
# The ATN XPI is unsigned (experiment APIs; no META-INF) and the "latest.xpi"
# URL redirects, so we pin a store-local file:// install_url and allow weak
# signatures via Preferences. The XPI is lightly patched to disable the
# Conversations "Between" column by default (and on upgrade).
{
  flake.homeModules.thunderbird-gmail-conversation-view =
    { pkgs, ... }:
    let
      conversationsXpiSrc = pkgs.fetchurl {
        url = "https://addons.thunderbird.net/thunderbird/downloads/file/1051295/thunderbird_conversations-4.3.12-tb.xpi";
        hash = "sha256-Xdtk75dsI48nXQHXw+oRKPc3MM4roS6aCsZoPkQWLx4=";
        name = "thunderbird_conversations-4.3.12-tb.xpi";
      };

      # Conversations stores disableBetweenColumn in extension storage.local;
      # there is no Thunderbird pref. Patch defaults + force on init, and bump
      # the XPI version so file:// ExtensionSettings reinstalls the update.
      conversationsXpi =
        pkgs.runCommand "gconversation@xulforum.org.xpi"
          {
            nativeBuildInputs = [
              pkgs.unzip
              pkgs.zip
              pkgs.python3
            ];
            src = conversationsXpiSrc;
          }
          ''
            unpack=$(mktemp -d)
            unzip -q -d "$unpack" "$src"
            python3 - "$unpack" <<'PY'
            import sys
            from pathlib import Path

            root = Path(sys.argv[1])
            prefs = root / "background/prefs.mjs"
            text = prefs.read_text()
            text = text.replace(
                "disableBetweenColumn: false,",
                "disableBetweenColumn: true,",
                1,
            )
            needle = (
                "      if (updatePrefs) {\n"
                "        try {\n"
                "          await browser.storage.local.set({ preferences: results.preferences });\n"
            )
            insert = (
                "      if (results.preferences.disableBetweenColumn !== true) {\n"
                "        results.preferences.disableBetweenColumn = true;\n"
                "        updatePrefs = true;\n"
                "      }\n"
                "\n"
                + needle
            )
            if needle not in text:
                raise SystemExit("prefs.mjs init needle not found")
            prefs.write_text(text.replace(needle, insert, 1))

            manifest = root / "manifest.json"
            manifest.write_text(
                manifest.read_text().replace('"version": "4.3.12"', '"version": "4.3.12.1"', 1)
            )
            PY
            (cd "$unpack" && zip -q -r "$out" .)
          '';
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
          "mail.pane_config.dynamic" = {
            Value = 2;
            Status = "user";
          };
          "mailnews.default_sort_type" = {
            Value = 18;
            Status = "user";
          };
          "mailnews.default_sort_order" = {
            Value = 2;
            Status = "user";
          };
        };
      };
    };
}
