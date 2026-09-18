{ lib, ... }:
{
  options.my.desktop.hyprland.appearance = {
    enable = lib.mkEnableOption "Hyprland visual appearance settings (opacity, rounding, blur, shadow)";

    windowOpacity = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable window opacity. Sets decoration:active_opacity and decoration:inactive_opacity for global window transparency.";
      };

      focused = lib.mkOption {
        type = lib.types.float;
        default = 0.97;
        example = 0.95;
        description = "Opacity for focused/active windows (0.0 = fully transparent, 1.0 = fully opaque).";
      };

      unfocused = lib.mkOption {
        type = lib.types.float;
        default = 0.92;
        example = 0.85;
        description = "Opacity for unfocused/inactive windows (0.0 = fully transparent, 1.0 = fully opaque).";
      };

      overrides = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            class = lib.mkOption {
              type = lib.types.str;
              example = "steam";
              description = "Window class to match. Use hyprctl clients to discover class names.";
            };
            focused = lib.mkOption {
              type = lib.types.float;
              default = 1.0;
              description = "Opacity when focused (0.0-1.0).";
            };
            unfocused = lib.mkOption {
              type = lib.types.float;
              default = 1.0;
              description = "Opacity when unfocused (0.0-1.0).";
            };
          };
        });
        default = [ ];
        example = [
          { class = "steam"; focused = 1.0; unfocused = 1.0; }
          { class = "mpv"; focused = 0.99; }
        ];
        description = "Per-class opacity overrides for specific applications. All values default to 1.0.";
      };
    };

    rounding = lib.mkOption {
      type = lib.types.int;
      default = 8;
      example = 12;
      description = "Window corner rounding radius in pixels.";
    };

    blur = {
      enable = lib.mkEnableOption "window blur effect";

      size = lib.mkOption {
        type = lib.types.int;
        default = 6;
        description = "Blur size (number of passes).";
      };

      passes = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Number of blur passes. Higher = more blur but more GPU usage.";
      };
    };

    shadow = {
      enable = lib.mkEnableOption "window shadows";

      range = lib.mkOption {
        type = lib.types.int;
        default = 12;
        description = "Shadow range (size) in pixels.";
      };

      renderPower = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Shadow render power (1-4). Higher = sharper shadow.";
      };

      color = lib.mkOption {
        type = lib.types.str;
        default = "rgba(1a1a2ecc)";
        example = "rgba(000000aa)";
        description = "Shadow color in RGBA format.";
      };
    };
  };
}
