{ lib, config, pkgs, flake, ... }:
let
  inherit (lib) mkIf;
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

      # Upstream stylix defaults to qt.platformTheme.name = "gnome",
      # but that's deprecated — "adwaita" is the replacement.
      targets.gnome.enable = config.my.desktop.gnome.enable or false;

      # On GNOME desktops stylix auto-selects stylix.targets.qt.platform = "gnome",
      # whose qt.platformTheme.name is now deprecated in nixpkgs ("use adwaita
      # instead" — but the NixOS enum only accepts gnome/gtk2/kde/lxqt/qt5ct).
      # Pin it to "qtct" (stylix's supported mode → qt5ct theme): silences both
      # stylix's "unsupported platform" warning and the nixpkgs deprecation,
      # and matches the qt5ct theming non-GNOME hosts already get.
      targets.qt.platform = lib.mkForce "qtct";
    };

    # Stylix's firefox target lives in its home-manager module (auto-imported
    # only when stylix is enabled) and warns unless profileNames is set. The
    # home firefox module (modules/home/firefox) creates a profile named after
    # the user's home-dir username, so declare that profile here. This must be
    # a (conditional) sharedModules *import*, not a plain config definition,
    # because hosts without stylix never import the stylix HM module and would
    # fail on a definition of the missing `stylix.targets.firefox` option.
    #
    # Same channel for zed: the target option exists only in stylix's HM module.
    # Disable it so the dedicated zed home module (my.programs.zed-editor) is the
    # single source of truth for settings.json — it generates a full dark
    # Catppuccin Mocha theme from me.colorScheme. Stylix's zed target sets
    # userSettings at normal priority, clobbering the module's mkDefault settings
    # wholesale, and its generated theme is invalid for zed ("Base16 untitled",
    # appearance "unspecified" — our base16Scheme lacks name/variant), so zed
    # rejects it and falls back to the default LIGHT theme.
    home-manager.sharedModules = [
      {
        stylix.targets.firefox.profileNames = [ me.username ];
      }
      {
        stylix.targets.zed.enable = lib.mkDefault false;
      }
    ];

    qt.platformTheme = lib.mkDefault "adwaita";
  };
}
