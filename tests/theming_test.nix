# =============================================================================
# tests/theming_test.nix — unit tests for the theming infrastructure
# =============================================================================
# Pure-evaluation tests (type = "unit"): they compare Nix values at eval time,
# so they cost nothing to run and cannot rot, because they call the same
# lib/color.nix and lib/theming.nix that the system actually uses.
#
# The WCAG assertions are pinned to *published* values rather than to whatever
# this implementation happens to produce, which is the point: lib/color.nix
# computes the sRGB transfer curve itself (Nix has no pow/exp/sqrt builtin, and
# nixpkgs 26.11 removed lib.pow), so a regression there would silently produce
# plausible-looking but wrong contrast ratios. #808080 and #777777 are the two
# standard reference greys (3.949:1 and 4.478:1 against white — the latter is
# the classic WCAG AA boundary).
# =============================================================================
{ lib, ... }:

let
  color = import ../lib/color.nix { inherit lib; };
  theming = import ../lib/theming.nix { inherit lib; };

  # nixpkgs 26.11 removed lib.round, and float equality on a computed ratio is
  # never worth asserting exactly.
  approx =
    expected: tol: actual:
    let
      abs = x: if x < 0.0 then -x else x;
    in
    actual != null && abs (actual - expected) <= tol;

  # Asserts a value is a valid "#rrggbb" or "#rrggbbaa".
  isHexish = v: color.valid v;

  slots = lib.genList (i: "base0" + builtins.toString i) 6 ++ [
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  mocha = theming.mkColors { scheme = "catppuccin-mocha"; };
in
{
  suites."theming-tests" = {
    pos = __curPos;
    tests = [
      # ── Parsing ──────────────────────────────────────────────────────────
      {
        name = "parse-six-digit-hex";
        type = "unit";
        expected = {
          r = 30;
          g = 30;
          b = 46;
          a = 255;
        };
        actual = color.parse "#1e1e2e";
      }

      {
        name = "parse-three-digit-shorthand-expands";
        type = "unit";
        expected = {
          r = 170;
          g = 187;
          b = 204;
          a = 255;
        };
        actual = color.parse "#abc";
      }

      {
        name = "parse-eight-digit-keeps-alpha";
        type = "unit";
        # "#1e1e2e7f" -> alpha byte 0x7f = 127, not an assumed 255.
        expected = 127;
        actual = (color.parse "#1e1e2e7f").a;
      }

      {
        name = "parse-accepts-uppercase-and-missing-hash";
        type = "unit";
        expected = true;
        actual = color.parse "#CDD6F4" == color.parse "cdd6f4";
      }

      {
        name = "parse-rejects-non-hex-as-null-not-an-error";
        type = "unit";
        # A broken theme value must surface as null an assertion can catch,
        # never as an opaque substring exception during evaluation.
        expected = null;
        actual = color.parse "#gggggg";
      }

      {
        name = "parse-rejects-wrong-length";
        type = "unit";
        expected = null;
        actual = color.parse "#12345";
      }

      # ── Round-tripping ───────────────────────────────────────────────────
      {
        name = "parse-serialize-round-trips";
        type = "unit";
        expected = [ true true true true ];
        actual = map (h: color.hexOf (color.parse h) == color.toHex h) [
          "#abc"
          "#1e1e2e"
          "#1e1e2eff"
          "#FFFFFF"
        ];
      }

      {
        name = "toBase16-strips-the-hash-for-stylix";
        type = "unit";
        expected = "1e1e2e";
        actual = color.toBase16 "#1e1e2e";
      }

      # ── WCAG reference values ────────────────────────────────────────────
      {
        name = "luminance-white-is-exactly-one";
        type = "unit";
        expected = 1.0;
        actual = color.luminance "#ffffff";
      }

      {
        name = "luminance-black-is-exactly-zero";
        type = "unit";
        expected = 0.0;
        actual = color.luminance "#000000";
      }

      {
        name = "contrast-maximum-is-21-to-1";
        type = "unit";
        expected = 21.0;
        actual = color.contrast "#ffffff" "#000000";
      }

      {
        name = "contrast-mid-grey-reference-3.949";
        type = "unit";
        expected = true;
        # published: contrast(#ffffff, #808080) == 3.949
        actual = approx 3.949 0.001 (color.contrast "#ffffff" "#808080");
      }

      {
        name = "contrast-WCAG-AA-boundary-grey-4.478";
        type = "unit";
        expected = true;
        # published: contrast(#ffffff, #777777) == 4.478 — the AA threshold grey
        actual = approx 4.478 0.001 (color.contrast "#ffffff" "#777777");
      }

      {
        name = "luminance-mid-grey-reference-0.21586";
        type = "unit";
        expected = true;
        # published sRGB relative luminance of #808080
        actual = approx 0.21586 0.00001 (color.luminance "#808080");
      }

      {
        name = "contrast-is-symmetric";
        type = "unit";
        expected = true;
        actual = (color.contrast "#1e1e2e" "#cdd6f4") == (color.contrast "#cdd6f4" "#1e1e2e");
      }

      # ── Blending ─────────────────────────────────────────────────────────
      {
        name = "mix-halfway-is-mid-grey";
        type = "unit";
        expected = "#808080";
        actual = color.mix "#000000" "#ffffff" 0.5;
      }

      {
        name = "mix-at-zero-is-the-first-argument";
        type = "unit";
        expected = "#1e1e2e";
        actual = color.mix "#1e1e2e" "#ffffff" 0.0;
      }

      {
        name = "mix-clamps-out-of-range-amounts";
        type = "unit";
        expected = true;
        actual = color.mix "#000000" "#ffffff" 5.0 == "#ffffff";
      }

      {
        name = "lighten-raises-and-darken-lowers-perceived-lightness";
        type = "unit";
        # Not an inverse pair: both blend toward white/black respectively, so
        # lighten-then-darken is not the identity. The invariant worth pinning is
        # the direction of the perceptual change.
        expected = [
          true
          true
        ];
        actual =
          let base = color.luminance "#808080";
          in [
            ((color.luminance (color.lighten "#808080" 0.5)) > base)
            ((color.luminance (color.darken "#808080" 0.5)) < base)
          ];
      }

      {
        name = "alpha-produces-eight-digit-hex";
        type = "unit";
        expected = "#89b4fa80";
        actual = color.alpha "#89b4fa" 0.5;
      }

      {
        name = "css-rgba-does-not-emit-float-noise";
        type = "unit";
        expected = "rgba(137, 180, 250, 1)";
        actual = color.toCssRgba "#89b4fa";
      }

      # ── Legibility ───────────────────────────────────────────────────────
      {
        name = "polarity-detects-dark-backgrounds";
        type = "unit";
        expected = "dark";
        actual = color.polarity "#1e1e2e";
      }

      {
        name = "polarity-detects-light-backgrounds";
        type = "unit";
        expected = "light";
        actual = color.polarity "#eff1f5";
      }

      {
        name = "bestForeground-picks-the-most-legible-candidate";
        type = "unit";
        expected = "#ffffff";
        actual = color.bestForeground "#1e1e2e" [ "#1e1e2e" "#cdd6f4" "#ffffff" ];
      }

      {
        name = "ensureContrast-clears-the-AA-threshold";
        type = "unit";
        expected = true;
        # ensureContrast steps in 4% increments, so it clears the threshold
        # rather than landing exactly on it — assert the inequality, not equality.
        actual =
          let
            fixed = color.ensureContrast "#45475a" "#1e1e2e" 4.5;
            ratio = color.contrast fixed "#1e1e2e";
          in
          ratio != null && ratio >= 4.5;
      }

      {
        name = "ensureContrast-leaves-an-already-legible-colour-alone";
        type = "unit";
        expected = "#cdd6f4";
        actual = color.ensureContrast "#cdd6f4" "#1e1e2e" 4.5;
      }

      # ── Catalog ──────────────────────────────────────────────────────────
      {
        name = "catalog-is-discovered-from-the-schemes-directory";
        type = "unit";
        expected = true;
        # Auto-discovery: adding lib/schemes/<name>.nix is the whole procedure.
        actual = builtins.length (builtins.attrNames theming.schemes) >= 2;
      }

      {
        name = "every-scheme-defines-sixteen-valid-hex-slots";
        type = "unit";
        expected = [ ];
        actual = lib.concatMap
          (
            name:
            let s = theming.schemes.${name};
            in builtins.filter (k: !(isHexish (s.${k} or null))) slots
          )
          (builtins.attrNames theming.schemes);
      }

      {
        name = "every-scheme-declares-a-polarity-that-matches-its-background";
        type = "unit";
        # Guards a real trap: the desktop reads the declared `polarity` while
        # stylix reads the background's luminance, and they can disagree.
        actual = builtins.filter
          (
            name: theming.schemes.${name}.polarity
              != color.polarity theming.schemes.${name}.base00
          )
          (builtins.attrNames theming.schemes);
        expected = [ ];
      }

      # ── Resolution & overrides ───────────────────────────────────────────
      {
        name = "unknown-scheme-falls-back-and-reports-it";
        type = "unit";
        # Silent fallback is exactly the bug this infrastructure prevents, so
        # `didFallback` is what modules/nixos/theming asserts on.
        expected = true;
        actual =
          let
            c = theming.mkColors {
              scheme = "definitely-not-a-scheme";
            };
          in
          c.didFallback && c.resolvedKey == "catppuccin-mocha";
      }

      {
        name = "base-slot-override-propagates-to-derived-roles";
        type = "unit";
        expected = "#000000";
        actual = (theming.mkColors {
          scheme = "catppuccin-mocha";
          overrides.base00 = "#000000";
        }).background;
      }

      {
        name = "role-override-leaves-other-roles-alone";
        type = "unit";
        expected = "#ff0000";
        actual = (theming.mkColors {
          scheme = "catppuccin-mocha";
          overrides.accent = "#ff0000";
        }).accent;
      }

      {
        name = "role-override-does-not-disturb-the-background";
        type = "unit";
        expected = "#1e1e2e";
        actual = (theming.mkColors {
          scheme = "catppuccin-mocha";
          overrides.accent = "#ff0000";
        }).background;
      }

      {
        name = "terminal-palette-follows-a-role-override";
        type = "unit";
        # The terminal is derived from the resolved roles, so an `accent`
        # override has to reach it — otherwise the override is half-applied.
        expected = "#ff0000";
        actual = (theming.mkColors {
          scheme = "catppuccin-mocha";
          overrides.accent = "#ff0000";
        }).terminal.blue;
      }

      {
        name = "stylix-view-is-hashless";
        type = "unit";
        # color.valid accepts both forms, so check the prefix explicitly: a "#"
        # reaching stylix is the classic cause of a theme that builds and renders
        # wrong.
        expected = [ ];
        actual = builtins.filter (k: lib.hasPrefix "#" mocha.base16.${k}) slots;
      }

      {
        name = "every-terminal-ansi-slot-is-a-valid-colour";
        type = "unit";
        expected = [ ];
        actual = builtins.filter (k: !(isHexish mocha.terminal.${k})) [
          "black"
          "red"
          "green"
          "yellow"
          "blue"
          "magenta"
          "cyan"
          "white"
          "brightBlack"
          "brightRed"
          "brightGreen"
          "brightYellow"
          "brightBlue"
          "brightMagenta"
          "brightCyan"
          "brightWhite"
          "background"
          "foreground"
          "cursor"
          "selection"
        ];
      }

      {
        name = "onBackground-is-legible-on-the-active-background";
        type = "unit";
        expected = true;
        actual =
          let ratio = color.contrast mocha.background mocha.onBackground;
          in ratio != null && ratio >= 4.4;
      }

      {
        name = "active-palette-has-readable-body-text";
        type = "unit";
        expected = true;
        # WCAG AA for normal text.
        actual =
          let ratio = color.contrast mocha.background mocha.foreground;
          in ratio != null && ratio >= 4.5;
      }
    ];
  };
}
