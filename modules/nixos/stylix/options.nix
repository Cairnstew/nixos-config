{ lib, flake, ... }:
let
  cfg = flake.config;
  prefs = cfg.preferences or { };
in
{
  options.my.theming.stylix = {
    enable = lib.mkEnableOption "Stylix theming framework (auto-themes apps via base16)";

    polarity = lib.mkOption {
      type = lib.types.enum [ "dark" "light" ];
      default = if prefs.darkMode or true then "dark" else "light";
      description = "Theme polarity. Defaults from preferences.darkMode.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Wallpaper image path. Null leaves existing wallpaper unchanged.";
      example = ./wallpapers/catppuccin-mocha.png;
    };
  };
}
