{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.my.programs.firefox = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Firefox with custom configuration";
    };

    package = mkOption {
      type = types.package;
      default = null;
      description = "The Firefox package to use. Defaults to pkgs.firefox.";
      example = lib.literalExpression "pkgs.firefox-wayland";
    };

    username = mkOption {
      type = types.str;
      default = config.home.username;
      description = "Username for Firefox profile";
    };

    extensions = mkOption {
      type = types.listOf types.str;
      default = [ "ublock-origin" "1password" ];
      description = ''
        Firefox extensions to install declaratively via Enterprise Policy
        (ExtensionSettings). Available names:
        - "ublock-origin" - uBlock Origin ad blocker
        - "1password" - 1Password password manager

        Extensions are downloaded and managed by Firefox itself; no manual
        XPI fetching or hash pinning is required.
      '';
      example = lib.literalExpression ''
        [ "ublock-origin" "1password" ]
      '';
    };

    extensionsInstallMode = mkOption {
      type = types.enum [ "force_installed" "normal_installed" ];
      default = "force_installed";
      description = ''
        Installation mode for configured extensions.
        - "force_installed" — silently install and prevent user uninstallation
        - "normal_installed" — install but allow user to uninstall
      '';
    };

    blockUnknownExtensions = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Block all extensions/add-ons that are not explicitly listed in
        ExtensionSettings. Recommended for security and reproducibility.
      '';
    };

    bookmarks = mkOption {
      type = types.listOf (
        types.either types.attrs types.str
      );
      default = [
        {
          name = "wikipedia";
          tags = [ "wiki" ];
          keyword = "wiki";
          url = "https://en.wikipedia.org/wiki/Special:Search?search=%s&amp;go=Go";
        }
        {
          name = "kernel.org";
          url = "https://www.kernel.org";
        }
        "separator"
        {
          name = "Nix sites";
          toolbar = true;
          bookmarks = [
            {
              name = "homepage";
              url = "https://nixos.org/";
            }
            {
              name = "wiki";
              tags = [ "wiki" "nix" ];
              url = "https://wiki.nixos.org/";
            }
          ];
        }
      ];
      description = "Firefox bookmarks configuration";
      example = lib.literalExpression ''
        [
          {
            name = "Example";
            url = "https://example.com";
          }
        ]
      '';
    };

    forceBookmarks = mkOption {
      type = types.bool;
      default = true;
      description = "Force bookmark configuration (overwrite existing)";
    };

    enableGnomeExtensions = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the GNOME Shell native host connector.
        Note: requires NixOS option `services.gnome.gnome-browser-connector.enable = true`.
      '';
    };
  };
}
