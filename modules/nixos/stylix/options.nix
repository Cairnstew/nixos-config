{ lib, config, ... }:

{
  options.my.theming.stylix = {
    enable = lib.mkEnableOption "Stylix theming framework (auto-themes apps via base16)";

    polarity = lib.mkOption {
      type = lib.types.enum [ "dark" "light" ];
      default = config.my.theming.polarity;
      description = ''
        Theme polarity.

        Defaults to the polarity of the active scheme (my.theming.polarity),
        so switching `theming.scheme` switches this too. Set it explicitly only
        to disagree with the scheme on purpose.
      '';
    };

    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Wallpaper image path. Null leaves existing wallpaper unchanged.";
      example = ./wallpapers/catppuccin-mocha.png;
    };
  };
}
