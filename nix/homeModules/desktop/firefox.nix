{ inputs, ... }:

let
  lock = value: {
    Value = value;
    Status = "locked";
  };

  firefoxPolicies = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    EnableTrackingProtection = {
      Value = true;
      Locked = true;
      Cryptomining = true;
      Fingerprinting = true;
    };
    DisablePocket = true;
    DisableFirefoxAccounts = true;
    DisableAccounts = true;
    DisableFirefoxScreenshots = true;
    OverrideFirstRunPage = "";
    OverridePostUpdatePage = "";
    DontCheckDefaultBrowser = true;
    DisplayBookmarksToolbar = "always";
    DisplayMenuBar = "always";
    SearchBar = "unified"; # alternative: "separate"
    PasswordManagerEnabled = false;
    ExtensionSettings = {
      # blocks all addons except the ones specified below
      "*".installation_mode = "blocked";
      # uBlock Origin:
      "uBlock0@raymondhill.net" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        installation_mode = "force_installed";
        default_area = "navbar";
        private_browsing = true;
      };
      # BitWarden
      "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/file/4842111/bitwarden_password_manager-2026.5.1.xpi";
        installation_mode = "force_installed";
        default_area = "navbar";
        private_browsing = true;
      };
    };

    Preferences = {
      "extensions.pocket.enabled" = lock false;
      "extensions.screenshots.disabled" = lock true;
      "browser.topsites.contile.enabled" = lock false;
      "browser.formfill.enable" = lock false;
      "browser.search.suggest.enabled" = lock false;
      "browser.search.suggest.enabled.private" = lock false;
      "browser.urlbar.suggest.searches" = lock false;
      "browser.urlbar.showSearchSuggestionsFirst" = lock false;
      "browser.newtabpage.activity-stream.feeds.section.topstories" = lock false;
      "browser.newtabpage.activity-stream.feeds.snippets" = lock false;
      "browser.newtabpage.activity-stream.section.highlights.includePocket" = lock false;
      "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = lock false;
      "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = lock false;
      "browser.newtabpage.activity-stream.section.highlights.includeVisited" = lock false;
      "browser.newtabpage.activity-stream.showSponsored" = lock false;
      "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock false;
      "browser.newtabpage.activity-stream.system.showSponsored" = lock false;
      "browser.contextual-password-manager.enabled" = lock false;
      "sidebar.verticalTabs" = lock true;
    };
  };

  xdgAssociations = {
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/about" = "firefox.desktop";
    "x-scheme-handler/unknown" = "firefox.desktop";
  };
in

{
  flake.homeModules.firefox =
    { config, pkgs, ... }:
    {
      programs.firefox = {
        enable = true;
        policies = firefoxPolicies;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
      };

      home.sessionVariables = {
        DEFAULT_BROWSER = "${pkgs.firefox}/bin/firefox";
        BROWSER = "${pkgs.firefox}/bin/firefox";
      };

      xdg.mimeApps.associations.added = xdgAssociations;
    };

  flake.homeModules.firefoxNixGL =
    { config, pkgs, ... }:
    let
      firefoxWrapped = config.lib.nixGL.wrap pkgs.firefox;
    in
    {
      programs.firefox = {
        enable = true;
        package = firefoxWrapped;
        policies = firefoxPolicies;
      };

      home.sessionVariables = {
        DEFAULT_BROWSER = "${firefoxWrapped}/bin/firefox";
        BROWSER = "${firefoxWrapped}/bin/firefox";
      };

      xdg.mimeApps.associations.added = xdgAssociations;
    };
}
