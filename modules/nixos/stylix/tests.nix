# Assertions for the stylix integration.
#
# The palette itself is validated by modules/nixos/theming/tests.nix — that is
# the single source of truth now, and duplicating the checks here would let the
# two drift. What is worth asserting here is the stylix-specific contract: that
# stylix receives a *complete, hashless* base16 scheme, because stylix silently
# renders a broken theme rather than failing when a slot is missing or still
# carries a leading "#".
{ config, lib, ... }:

let
  cfg = config.my.theming.stylix;
  theme = config.my.theming.colors;
  base16 = theme.base16;

  slots = lib.genList (i: "base0" + builtins.toString i) 6 ++ [ "base0A" "base0B" "base0C" "base0D" "base0E" "base0F" ];

  missing = builtins.filter (s: !(base16 ? ${s})) slots;

  # A stylix base16 value must be 6 bare hex digits. A "#" prefix is the single
  # most common cause of a theme that evaluates fine and looks wrong.
  withHash = builtins.filter (s: base16 ? ${s} && lib.hasPrefix "#" base16.${s}) slots;

  wrongWidth = builtins.filter
    (
      s: base16 ? ${s} && lib.stringLength base16.${s} != 6
    )
    slots;
in
{
  assertions = [
    {
      assertion = !cfg.enable || missing == [ ];
      message = "stylix.base16Scheme is missing slots: ${lib.concatStringsSep ", " missing}. Set theming.scheme to a complete scheme.";
    }

    {
      assertion = !cfg.enable || withHash == [ ];
      message = ''
        stylix.base16Scheme slots must not carry a "#" prefix, but these do:
        ${lib.concatStringsSep ", " withHash}. my.theming.colors.base16 already
        strips it — check that this is still what stylix is being given.
      '';
    }

    {
      assertion = !cfg.enable || wrongWidth == [ ];
      message = "stylix.base16Scheme slots must be 6 hex digits; these are not: ${lib.concatStringsSep ", " wrongWidth}.";
    }

    {
      assertion = !cfg.enable || cfg.polarity == theme.polarity;
      message = ''
        my.theming.stylix.polarity ("${cfg.polarity}") disagrees with the active
        scheme's polarity ("${theme.polarity}"). Stylix uses polarity to pick
        between light and dark templates, so this renders the wrong variant.
        Either drop the override or set a scheme that matches.
      '';
    }
  ];
}
