{ lib, ... }:
{
  options.my.desktop.hyprland.appearance = {
    enable = lib.mkEnableOption ''
      palette-derived Hyprland decoration colours (active/inactive border gradient,
      shadow colour) applied as defaults over my.desktop.hyprland.settings''
    ;

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
      description = ''
        Per-class opacity overrides (window rules). Global opacity is
        `my.desktop.hyprland.settings.decoration.active_opacity` /
        `inactive_opacity`.
      '';
    };
  };
}
