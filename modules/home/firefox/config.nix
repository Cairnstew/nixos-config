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
  };
}
