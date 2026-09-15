{ config, pkgs, lib, ... }:
let
  knownExtensions = import ./extensions.nix;

  cfg = config.my.programs.firefox;

  # Build the ExtensionSettings policy entries from the configured names.
  extensionPolicies = lib.listToAttrs (
    builtins.map
      (
        name:
        let
          ext = knownExtensions.${name};
        in
        lib.nameValuePair ext.guid {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${ext.shortId}/latest.xpi";
          installation_mode = cfg.extensionsInstallMode;
        }
      )
      cfg.extensions
  );
in
{
  config = lib.mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      package = lib.mkDefault pkgs.firefox;

      enableGnomeExtensions = cfg.enableGnomeExtensions;

      policies = {
        ExtensionSettings =
          lib.optionalAttrs cfg.blockUnknownExtensions { "*".installation_mode = "blocked"; }
          // extensionPolicies;
      };

      profiles.${cfg.username} = {
        isDefault = true;
        bookmarks = {
          force = cfg.forceBookmarks;
          settings = cfg.bookmarks;
        };
      };
    };

    # Firefox DevTools MCP for OpenCode
    # When firefox.enable = true, this adds the MCP server configuration
    # that OpenCode reads under my.programs.opencode.mcp.firefox-devtools.
    # When firefox.enable = false, no MCP entry is added (single source of truth).
    # Note: @0.10.1 pins the npm package to a specific version for reproducibility.
    # Node.js and npx must be available in OpenCode's execution environment.
    # The npm package itself remains a runtime network dependency.
    my.programs.opencode.mcp.firefox-devtools = {
      enabled = true;
      type = "local";
      command = [
        "npx"
        "-y"
        "@mozilla/firefox-devtools-mcp@0.10.1"
        "--headless"
        "--viewport"
        "1280x720"
      ];
      environment = {
        START_URL = "about:blank";
        FIREFOX_HEADLESS = "true";
      };
      timeout = 120000;
    };
  };
}
