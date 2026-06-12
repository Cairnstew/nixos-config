{ lib, ... }:
let
  inherit (lib) types;
in
{
  options.my.gnomeExtensions.custom = {
    extensions = lib.mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          enable = lib.mkEnableOption "this GNOME Shell extension";

          uuid = lib.mkOption {
            type = types.str;
            default = "${name}@custom";
            defaultText = lib.literalExpression ''"<name>@custom"'';
            description = "Extension UUID (e.g. 'my-ext@custom'). Auto-generated from the attribute name.";
          };

          name = lib.mkOption {
            type = types.str;
            default = name;
            defaultText = lib.literalExpression ''"<name>"'';
            description = "Human-readable extension name displayed in GNOME Extensions app.";
          };

          description = lib.mkOption {
            type = types.str;
            default = "";
            description = "Short description of what the extension does.";
          };

          version = lib.mkOption {
            type = types.int;
            default = 1;
            description = "Extension version number.";
          };

          shellVersions = lib.mkOption {
            type = types.listOf types.str;
            default = [ "49" ];
            description = "List of supported GNOME Shell version strings (e.g. '45', '46', '47').";
          };

          url = lib.mkOption {
            type = types.str;
            default = "";
            description = "Extension website or repository URL.";
          };

          extensionJs = lib.mkOption {
            type = types.str;
            default = "";
            description = ''
              Content of extension.js — the main extension code.
              Supports Nix string interpolation, so you can inject config values
              (e.g. ${"$"}{config.networking.hostName}) at build time.
            '';
          };

          stylesheetCss = lib.mkOption {
            type = types.str;
            default = "";
            description = "Content of stylesheet.css (optional).";
          };

          extraFiles = lib.mkOption {
            type = types.attrsOf types.anything;
            default = { };
            description = ''
              Additional files to include in the extension directory.
              Keys are filenames, values are either Nix paths (source files)
              or strings (inline text). Useful for splitting large extensions
              into multiple files.
            '';
          };
        };
      }));
      default = { };
      description = ''
        Custom GNOME Shell extensions defined declaratively in Nix.
        Each attribute name becomes the extension's internal name.
        The extensionJs option supports config interpolation, letting you
        inject Nix configuration values into your extension code.
      '';
      example = lib.literalExpression ''
        {
          host-info = {
            enable = true;
            description = "Shows hostname in the top bar";
            extensionJs = # js
              ''''
                const St = imports.gi.St;
                const Main = imports.ui.main;
                const PanelMenu = imports.ui.panelMenu;

                const hostname = "${"$"}{config.networking.hostName}";

                const indicator = new PanelMenu.Button(0.0, "host-info", false);
                const label = new St.Label({ text: hostname, y_align: 3 });
                indicator.add_child(label);
                Main.panel.addToStatusArea("host-info", indicator);
              '''';
          };
        }
      '';
    };
  };
}
