# my.theming.* — read-only view of the resolved palette for Home Manager
# modules. The NixOS-side twin of modules/nixos/theming.
#
# Home Manager gets every module in modules/home/ as a shared module (see
# modules/nixos/homeManager/config.nix: `builtins.attrValues self.homeModules`),
# so this lands on every user of every host with no per-host wiring.
#
# No `enable` option, for the same reason as the NixOS twin: the palette is
# inert data, and gating it would only push "attribute 'accent' missing"
# errors into consumer modules. Theming behaviour is gated by
# my.theming.stylix.enable in the NixOS module.
#
{ lib, ... }:

{
  options.my.theming = {
    colors = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      defaultText = lib.literalExpression ''
        "the resolved palette: base00-base0F plus semantic roles"
      '';
      description = ''
        The resolved colour palette, for Home Manager modules:

          my.theming.colors.background   — panel / editor background
          my.theming.colors.foreground   — primary text
          my.theming.colors.accent       — selections, focus, highlights
          my.theming.colors.terminal.*   — 16 ANSI colours + cursor
          my.theming.colors.base16       — hashless base16, for editors

        Example (lazygit border colour):

          settings.gui.theme.activeBorderColor = [
            (my.theming.colors.accent) "bold"
          ];
      '';
    };

    lib = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      defaultText = lib.literalExpression ''"the pure colour helpers, see my.theming.colors"'';
      description = ''
        Pure colour maths, no import required:

          my.theming.lib.color.contrast bg fg
          my.theming.lib.color.mix a b 0.5
          my.theming.lib.color.lighten hex 0.2
          my.theming.lib.color.ensureContrast fg bg 4.5
      '';
    };

    scheme = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      defaultText = lib.literalExpression ''"e.g. catppuccin-mocha — the active scheme slug"'';
      description = ''
        Slug of the scheme in use. For programs that take a theme *name*
        (helix, zed): note that helix wants dashes replaced by underscores,
        which is what `my.theming.schemeUnderscored` is for.
      '';
    };

    schemeUnderscored = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      defaultText = lib.literalExpression ''"the scheme slug with dashes as underscores"'';
      description = ''
        The scheme slug with "-" replaced by "_". Helix names its built-in
        themes `catppuccin_mocha`, not `catppuccin-mocha`.
      '';
    };

    polarity = lib.mkOption {
      type = lib.types.enum [ "dark" "light" ];
      readOnly = true;
      defaultText = lib.literalExpression ''"dark or light"'';
      description = "Whether the active scheme is a dark or a light theme.";
    };
  };
}
