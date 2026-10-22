{ lib, pkgs, ... }:

let
  types = lib.types;
in
{
  options.my.programs.obsidian = {
    enable = lib.mkEnableOption "Obsidian with custom configuration";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.obsidian;
      defaultText = lib.literalExpression "pkgs.obsidian";
      description = "The Obsidian package to use.";
    };

    defaultDirectory = lib.mkOption {
      type = types.str;
      default = "Documents/Obsidian_Vault";
      description = "Default vault directory relative to HOME";
    };

    plugins = lib.mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = lib.mkEnableOption "installing this plugin into the vault";

            version = lib.mkOption {
              type = types.str;
              example = "5.5.2";
              description = "Release tag of the plugin to install.";
            };

            repo = lib.mkOption {
              type = types.str;
              example = "coddingtonbear/obsidian-local-rest-api";
              description = ''
                GitHub repository (`owner/name`) that publishes the plugin's
                release assets (`main.js`, `manifest.json`, optional
                `styles.css`).
              '';
            };

            mainJsHash = lib.mkOption {
              type = types.str;
              example = "sha256-kElLZETF/t5dEvlzRqq4OSZbXHoJUg/oe078IjYLbNg=";
              description = "sha256 (SRI) of the `main.js` release asset.";
            };

            manifestHash = lib.mkOption {
              type = types.str;
              description = "sha256 (SRI) of the `manifest.json` release asset.";
            };

            stylesHash = lib.mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "sha256 (SRI) of the `styles.css` release asset, or null when the plugin ships none.";
            };
          };
        }
      );
      default = { };
      description = ''
        Obsidian community plugins to install into `<vault>/.obsidian/plugins/`,
        keyed by plugin id. Release assets are pinned by tag and sha256 and
        fetched at build time, so the installed plugin set is reproducible.

        The plugin directory stays writable and only the asset files are
        written, so plugin state (`data.json`, including API keys) survives
        switches.
      '';
    };

    repo = {
      enable = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Clone the Obsidian vault from a git repo on first setup";
      };

      url = lib.mkOption {
        type = types.str;
        default = "";
        description = "GitHub repo URL (e.g. https://github.com/user/vault)";
      };

      tokenFile = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to agenix-managed file containing a GitHub access token";
      };
    };
  };
}
