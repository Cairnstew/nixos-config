{ lib, config, pkgs, flake, ... }:
let
  inherit (lib) mkIf mkDefault;
  cfg = config.my.theming.stylix;
  me = flake.config.me;
  prefs = flake.config.preferences or { };
  scheme = me.colorScheme or { };

  strip = lib.removePrefix "#";

  # Build base16 attrset without # prefix for Stylix
  base16Scheme = lib.optionalAttrs (scheme ? base00) {
    slug = scheme.slug or "custom";
    base00 = strip scheme.base00;
    base01 = strip scheme.base01;
    base02 = strip scheme.base02;
    base03 = strip scheme.base03;
    base04 = strip scheme.base04;
    base05 = strip scheme.base05;
    base06 = strip scheme.base06;
    base07 = strip scheme.base07;
    base08 = strip scheme.base08;
    base09 = strip scheme.base09;
    base0A = strip scheme.base0A;
    base0B = strip scheme.base0B;
    base0C = strip scheme.base0C;
    base0D = strip scheme.base0D;
    base0E = strip scheme.base0E;
    base0F = strip scheme.base0F;
  };
in
{
  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      autoEnable = true;
      polarity = cfg.polarity;
      base16Scheme = base16Scheme;
      image = cfg.wallpaper;

      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = prefs.terminalFont or "JetBrainsMono Nerd Font";
        };
        sansSerif = {
          package = pkgs.inter;
          name = "Inter";
        };
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
        sizes = {
          applications = 10;
          desktop = 10;
          popups = 10;
          terminal = prefs.terminalFontSize or 11;
        };
      };

      cursor = {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
        size = 24;
      };
    };
  };
}
