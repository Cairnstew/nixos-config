{ lib, config, pkgs, flake, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.theming.stylix;
  me = flake.config.me;
  prefs = flake.config.preferences or { };

  # The resolved palette, from the shared theming infrastructure
  # (modules/nixos/theming). `base16` is the hashless base00-base0F attrset
  # plus slug/name/variant — exactly what stylix's `attrs` type wants, already
  # converted. Previously this module rebuilt it by hand from
  # `flake.config.me.colorScheme` with `lib.removePrefix "#"` on all sixteen
  # slots; that conversion now lives in one place (lib/theming.nix). The
  # `my.theming.colors` mirror of this module is the supported read API.
  theme = config.my.theming.colors;
in
{
  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      autoEnable = true;
      polarity = cfg.polarity;
      base16Scheme = theme.base16;
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
    # single source of truth for settings.json — it generates a full theme from
    # my.theming.colors. Stylix's zed target sets userSettings at normal
    # priority, clobbering the module's mkDefault settings wholesale, and its
    # generated theme is invalid for zed ("Base16 untitled", appearance
    # "unspecified"), so zed rejects it and falls back to the default LIGHT
    # theme. my.theming.colors.base16 now carries slug/name/variant, which is
    # what zed wants — but leaving stylix's target enabled would still clobber
    # the module's settings, so it stays off.
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
