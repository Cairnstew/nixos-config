# =============================================================================
# lib/color.nix — pure, dependency-free color mathematics
# =============================================================================
# The bottom layer of the repo's theming infrastructure. This file has NO
# dependency on the flake, on modules, or on any option system: it is a plain
# Nix function that any module, flake-parts layer, script, or one-off
# `nix eval` can import.
#
# Usage:
#   let color = import ./lib/color.nix { inherit lib; };
#   in color.contrast "#1e1e2e" "#cdd6f4"
#
# Design rules:
#   - Pure evaluation only. Nothing here builds derivations or touches IFD.
#   - Lenient parsing. Accepts "#rgb", "#rrggbb", "#rrggbbaa" and the same
#     without "#", upper or lower case. Use `valid`/`parse` to check first.
#   - Null on garbage, never an exception. A broken theme value should produce
#     a null that a module's assertion can catch, not blow up evaluation with
#     an opaque substring error.
#   - Round-trip safe. `hexOf (parse x) == toHex x` for every accepted input.
# =============================================================================

{ lib }:

let
  inherit (lib) foldl';

  # ── Low-level helpers ──────────────────────────────────────────────────

  digits = "0123456789abcdef";

  # Split a string into single-character strings. `lib.stringToList` does not
  # exist across the nixpkgs versions this repo spans, and `lib.splitString`
  # rejects an empty separator, so genList+substring is the portable form.
  chars = s: builtins.genList (i: builtins.substring i 1 s) (lib.stringLength s);

  isHexDigit = c: lib.elem c (chars digits);

  clamp = v: lo: hi: lib.min (lib.max v lo) hi;

  # [0.0, 1.0]
  clamp01 = v: clamp v 0.0 1.0;

  # Lowercase, strip a leading "#", validate every character.
  # Returns the bare digit string ("1e1e2e") or null.
  normalize = hex:
    let s = lib.toLower (lib.removePrefix "#" (lib.toString hex));
    in if s == "" || !(builtins.all isHexDigit (chars s)) then null else s;

  # Single hex character -> int 0..15.
  #
  # nixpkgs 26.11 removed both lib.stringToInt and lib.elemIndex, so this is
  # a table scan rather than a library call. Returns null for a non-hex char;
  # callers only ever run it on input that normalize() already validated.
  digitValue =
    c:
    let
      table = chars digits;
    in
    lib.findFirst (i: builtins.elemAt table i == c) null (lib.genList (i: i) 16);

  # "7f" -> 127
  byteOf = cs: i: (digitValue (builtins.elemAt cs i)) * 16 + digitValue (builtins.elemAt cs (i + 1));

  # "f" -> 15, used by the #rgb shorthand
  shortByteOf = cs: i: (digitValue (builtins.elemAt cs i)) * 16 + digitValue (builtins.elemAt cs i);

  hexByte =
    v:
    let
      n = builtins.floor ((clamp v 0 255) + 0.5);
      hi = builtins.floor (n / 16);
      lo = n - hi * 16;
    in
    lib.substring hi 1 digits + lib.substring lo 1 digits;

  # Null-coalescing helpers, kept local so the public surface stays a plain
  # function set with no `or` defaults to remember.
  numOr = fallback: v: if v == null then fallback else v;

  # ── Parse / serialize ──────────────────────────────────────────────────

  # hex -> { r, g, b, a } with r/g/b/a as ints 0-255, or null when invalid.
  parse =
    hex:
    let
      s = normalize hex;
      n = lib.stringLength s;
      cs = chars s;
    in
    if s == null then
      null
    else if n == 3 then
      {
        r = shortByteOf cs 0;
        g = shortByteOf cs 1;
        b = shortByteOf cs 2;
        a = 255;
      }
    else if n == 6 then
      {
        r = byteOf cs 0;
        g = byteOf cs 2;
        b = byteOf cs 4;
        a = 255;
      }
    else if n == 8 then
      {
        r = byteOf cs 0;
        g = byteOf cs 2;
        b = byteOf cs 4;
        a = byteOf cs 6;
      }
    else
      null;

  # { r, g, b } -> "#rrggbb" (drops any alpha channel)
  hexOf = c: "#" + hexByte c.r + hexByte c.g + hexByte c.b;

  # Canonical "#rrggbb", or null when unparseable.
  toHex =
    hex:
    let p = parse hex;
    in if p == null then null else hexOf p;

  # Canonical "#rrggbbaa" — always carries the alpha channel explicitly.
  toHexAlpha =
    hex:
    let p = parse hex;
    in if p == null then null else hexOf p + hexByte (p.a or 255);

  # The hashless form stylix and every base16 consumer expects.
  toBase16 =
    hex:
    let h = toHex hex;
    in if h == null then null else lib.removePrefix "#" h;

  valid = hex: parse hex != null;

  # ── Channel math ───────────────────────────────────────────────────────
  #
  # Nix has no exp/log/pow/sqrt builtin, and nixpkgs 26.11 removed lib.pow,
  # so the WCAG exponent is computed by hand:  x^2.4 == x^2 * (x^2)^(1/5).
  # The fifth root uses Newton's method, which converges monotonically from
  # above for any input in [0, 1] — the only range we feed it.
  ipow =
    e: base: lib.foldl' (a: _: a * base) 1.0 (lib.genList (i: i) e);

  fifthRoot =
    a:
    let
      # Guard the 0 case: Newton divides by y^4.
      target = lib.max a 1.0e-18;
      go =
        k: y:
        if k <= 0 then
          y
        else
          let y4 = ipow 4 y;
          in go (k - 1) (((4.0 * y) + (target / y4)) / 5.0);
    in
    go 40 1.0;

  pow24 =
    x:
    let sq = x * x;
    in sq * fifthRoot sq;

  # WCAG relative-luminance transfer function for one 0-255 channel.
  channelLum = v:
    let c = v / 255.0;
    in if c <= 0.03928 then c / 12.92 else pow24 ((c + 0.055) / 1.055);

  # WCAG relative luminance, 0.0 (black) .. 1.0 (white).
  luminance =
    hex:
    let p = parse hex;
    in
    if p == null then
      null
    else
      0.2126 * channelLum p.r + 0.7152 * channelLum p.g + 0.0722 * channelLum p.b;

  # WCAG contrast ratio, 1.0 .. 21.0. Null when either side is unparseable.
  contrast =
    a: b:
    let
      la = luminance a;
      lb = luminance b;
    in
    if la == null || lb == null then
      null
    else
      let
        hi = lib.max la lb;
        lo = lib.min la lb;
      in
      (hi + 0.05) / (lo + 0.05);

  # Linear blend. amount 0.0 -> a, 1.0 -> b. Values are clamped to 0.0-1.0.
  mix =
    a: b: amount:
    let
      pa = parse a;
      pb = parse b;
      t = clamp01 amount;
    in
    if pa == null || pb == null then
      null
    else
      hexOf {
        r = pa.r + (pb.r - pa.r) * t;
        g = pa.g + (pb.g - pa.g) * t;
        b = pa.b + (pb.b - pa.b) * t;
        a = pa.a + (pb.a - pa.a) * t;
      };

  lighten = hex: amount: mix hex "#ffffff" amount;

  darken = hex: amount: mix hex "#000000" amount;

  # Blend toward the grey that matches this color's perceived lightness.
  # Useful for "muted" / "subtle" variants that must keep reading as the same
  # lightness as the accent they were derived from.
  desaturate =
    hex: amount:
    let p = parse hex;
    in
    if p == null then
      null
    else
      let
        grey = builtins.floor ((numOr 0.0 (luminance hex) * 255.0) + 0.5);
      in
      mix hex
        (hexOf {
          r = grey;
          g = grey;
          b = grey;
        })
        amount;

  # ── Alpha ──────────────────────────────────────────────────────────────

  # hex -> "#rrggbbaa". amount is 0.0-1.0.
  alpha =
    hex: amount:
    let p = parse hex;
    in if p == null then null else hexOf p + hexByte (clamp01 amount * 255);

  # Alias with the name most consumers reach for first.
  withAlpha = alpha;

  # "#rrggbb" -> "rgba(r, g, b, 1)" for SVG / HTML / CSS output.
  #
  # Nix's toString on a float always emits six decimals ("1.000000"), which is
  # valid CSS but ugly in generated files, so the alpha is rendered from a
  # 3-digit scaled integer instead.
  toCssRgba =
    hex:
    let
      p = parse hex;
    in
    if p == null then
      null
    else
      let
        a = clamp01 ((p.a or 255) / 255.0);
        scaled = lib.floor (a * 1000.0 + 0.5);
        whole = lib.floor (scaled / 1000.0);
        # Integer arithmetic throughout: a float here makes toString emit
        # "94.000000" and the trimmed result ends in a stray dot.
        frac = scaled - (whole * 1000);
        fracPadded = (if frac < 10 then "00" else if frac < 100 then "0" else "") + toString frac;
        lastChar = s: lib.substring (lib.stringLength s - 1) 1 s;
        trimZeros = s: if lib.stringLength s > 1 && lastChar s == "0" then trimZeros (lib.removeSuffix "0" s) else s;
        fracText = if frac == 0 then "" else "." + trimZeros fracPadded;
      in
      "rgba(${toString p.r}, ${toString p.g}, ${toString p.b}, ${toString whole}${fracText})";

  # ── Polarity & legibility ──────────────────────────────────────────────

  # Below 0.5 perceived lightness counts as a dark background.
  isDark = hex: (numOr 0.0 (luminance hex)) < 0.5;

  polarity = hex: if isDark hex then "dark" else "light";

  # Pick whichever of `candidates` has the highest contrast against `bg`.
  # Order matters only as a tiebreak — the first candidate wins a tie.
  bestForeground =
    bg: candidates:
    let
      scored = map
        (fg: {
          inherit fg;
          score = numOr 0.0 (contrast bg fg);
        })
        candidates;
      best = foldl'
        (
          acc: x: if x.score > acc.score then x else acc
        )
        {
          fg = null;
          score = -1.0;
        }
        scored;
    in
    best.fg;

  # Nudge `fg` toward white (dark bg) or black (light bg) until it clears
  # `ratio`. Bounded at 24 steps of 4% so it terminates; returns the last
  # candidate rather than null when the target is unreachable.
  ensureContrast =
    fg: bg: ratio:
    let
      target = numOr 4.5 ratio;
      step = 0.04;
      darkBg = (numOr 0.0 (luminance bg)) < 0.5;
      go =
        n: h:
        let c = numOr 0.0 (contrast h bg);
        in
        if c >= target || n <= 0 || !(valid h) then
          h
        else
          go (n - 1) (if darkBg then lighten h step else darken h step);
    in
    go 24 fg;
in
{
  inherit
    parse
    hexOf
    toHex
    toHexAlpha
    toBase16
    valid
    luminance
    contrast
    mix
    lighten
    darken
    desaturate
    alpha
    withAlpha
    toCssRgba
    isDark
    polarity
    bestForeground
    ensureContrast
    clamp
    clamp01
    ;
}
