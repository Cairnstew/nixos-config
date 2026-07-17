{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types literalExpression;
in
{
  options.my.programs.godot = {
    enable = mkEnableOption "Godot game engine and game development tools";

    engine = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install the Godot Engine editor.";
      };

      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        example = literalExpression "pkgs.godot";
        description = ''
          Godot Engine package to use. When <literal>null</literal>, uses
          the latest stable version from nixpkgs.
        '';
      };

      headless = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Install the Godot headless/server build for CI/CD and automation.";
        };

        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = ''
            Headless Godot package. When <literal>null</literal> and enabled,
            will use the default headless package from nixpkgs if available.
          '';
        };
      };
    };

    exportTemplates = {
      enable = mkEnableOption "Godot export templates for building platform-specific releases";

      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = ''
          Export templates package. When <literal>null</literal>, uses the
          default templates from nixpkgs.
        '';
      };

      autoDownload = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Automatically place export templates in the Godot data directory
          so the editor can find them without manual setup.
        '';
      };

      targetDir = mkOption {
        type = types.str;
        default = ".local/share/godot/export_templates";
        description = ''
          Directory (relative to HOME) where export templates are placed.
          Default matches Godot's expected template location.
        '';
      };
    };

    gdscript = {
      enable = mkEnableOption "GDScript language tooling (linter, formatter, parser)";

      gdtoolkit = mkOption {
        type = types.bool;
        default = true;
        description = "Install gdtoolkit (GDScript parser, linter, and formatter for Godot 4).";
      };

      formatter = mkOption {
        type = types.bool;
        default = true;
        description = "Install gdscript-formatter (fast GDScript formatter).";
      };
    };

    mono = {
      enable = mkEnableOption "Godot Mono/C# support. When enabled, uses godot-mono (C# build) instead of regular Godot, and installs the .NET SDK.";
    };

    mcp = {
      enable = mkEnableOption "Godot MCP server for AI-assisted game development";

      port = mkOption {
        type = types.port;
        default = 3101;
        description = "Port for the Godot MCP server to listen on.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the MCP port in the firewall.";
      };
    };

    pckTool = mkEnableOption "godotpcktool for extracting and creating Godot .pck files";

    editor = {
      enable = mkEnableOption "Godot editor configuration via home-manager";

      settingsFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = literalExpression "./godot-editor-settings.tres";
        description = ''
          Path to a <filename>editor_settings.tres</filename> file to pre-populate
          the Godot editor settings. Useful for sharing editor config across machines.
        '';
      };

      projectManager = {
        favoriteDirectories = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "~/Projects/godot" "~/Games/mygame" ];
          description = "List of directories to show as favorites in the Godot project manager.";
        };

        defaultRenderers = mkOption {
          type = types.listOf types.str;
          default = [ "forward_plus" "mobile" "gl_compatibility" ];
          description = ''
            Default renderers shown in the project creation dialog.
            Order: preferred first, fallbacks after.
          '';
        };
      };
    };

    projects = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          path = mkOption {
            type = types.str;
            description = "Absolute path to the project directory.";
          };

          defaultScene = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "res://scenes/main.tscn";
            description = "Default main scene for this project.";
          };

          renderer = mkOption {
            type = types.enum [ "forward_plus" "mobile" "gl_compatibility" ];
            default = "forward_plus";
            description = "Rendering method for this project.";
          };

          xrMode = mkOption {
            type = types.enum [ "off" "openxr" "webxr" ];
            default = "off";
            description = "XR mode for this project.";
          };

          plugins = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "godot-steam" "godot-firebase" ];
            description = "Plugins enabled for this project.";
          };

          desktopEntries = {
            enable = mkEnableOption "desktop entry for this project";

            icon = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to an icon for the desktop entry.";
            };

            categories = mkOption {
              type = types.listOf types.str;
              default = [ "Game" ];
              description = "Desktop entry categories.";
            };
          };
        };
      });
      default = { };
      example = {
        my-game = {
          path = "/home/user/Projects/godot/my-game";
          defaultScene = "res://scenes/main.tscn";
          renderer = "forward_plus";
          desktopEntries.enable = true;
        };
      };
      description = ''
        Declared Godot projects. Each entry can create a desktop entry for
        launching the project directly with Godot.
      '';
    };

    companionApps = {
      enable = mkEnableOption "companion game development applications";

      pixelorama = mkOption {
        type = types.bool;
        default = false;
        description = "Pixelorama free & open-source 2D sprite editor (built with Godot).";
      };

      aseprite = mkOption {
        type = types.bool;
        default = false;
        description = "Aseprite animated sprite editor & pixel art tool.";
      };

      blender = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Blender 3D creation suite for 3D modelling, animation, and asset
          pipeline. Recommended for Godot 3D projects.
        '';
      };

      inkscape = mkOption {
        type = types.bool;
        default = false;
        description = "Inkscape vector graphics editor for 2D assets and UI mockups.";
      };

      audacity = mkOption {
        type = types.bool;
        default = false;
        description = "Audacity audio editor for sound effects and music editing.";
      };

      texturePacker = mkOption {
        type = types.bool;
        default = false;
        description = "TexturePacker sprite sheet creator and game graphics optimizer.";
      };

      tiled = mkOption {
        type = types.bool;
        default = false;
        description = "Tiled tile map editor for level design.";
      };

      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        example = literalExpression "[ pkgs.lmms pkgs.musescore ]";
        description = "Extra companion packages for game development (DAWs, music tools, etc.).";
      };
    };
  };
}
