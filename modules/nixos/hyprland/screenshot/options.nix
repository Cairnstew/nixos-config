{ lib, ... }:
{
  options.my.desktop.hyprland.screenshot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable screenshot tools (grim + slurp) with SUPER+SHIFT+S and Print keybinds.";
    };
    directory = lib.mkOption {
      type = lib.types.str;
      default = "~/Pictures";
      description = "Directory for saved screenshots.";
    };
  };
}
