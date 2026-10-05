# =============================================================================
# lib/theming.nix — scheme resolution and semantic-role derivation
# =============================================================================
# The middle layer of the repo's theming infrastructure. Turns one of the
# bare base16 palettes in `lib/schemes/` into the palette that modules
# actually consume.
#
# No dependency on the flake or on any module system; it is a plain function
# of `lib`. NixOS modules, Home Manager modules, flake-parts layers and
# ad-hoc scripts all import it the same way:
#
#   let theming = import ../../lib/theming.nix { inherit lib; };
#   in theming.mkColors { scheme = "nord"; }
#
# ── Why roles exist ──────────────────────────────────────────────────────
# A base16 palette has 16 unnamed slots. Every consumer wants names like
# "accent", "error" or "muted text", and each consumer used to re-derive
# those names from base16 by hand — which is how one colour ended up spelled
# three different ways in three different modules. Roles are derived once,
# here, from a single documented mapping.
#
# ── Why overrides are two-phase ──────────────────────────────────────────
# `overrides` are applied in two passes so the result is predictable:
#
#   pass 1  overrides targeting `base00`-`base0F` replace the raw palette and
#           the semantic roles are re-derived from it. Override `base00` and
#           `background`, `surface` and `selection` all follow.
#   pass 2  overrides targeting any role name are applied last and win.
#           Override `accent` and only that role changes.
#
# Later wins, always. A role override never fights a base override.
# =============================================================================

{ lib }:

let
  inherit (lib) foldl';

  # Concrete left-to-right overlay. `lib.mkMerge` would defer to the module
  # system, which leaves the result carrying `_type = "merge"` internals —
  # that breaks `builtins.attrNames`, `builtins.toJSON` and any consumer that
  # treats the palette as plain data. Precedence here is fully explicit (later
  # wins), so a plain fold is both clearer and friendlier.
  overlay = layers: foldl' (acc: layer: acc // layer) { } layers;

  color = import ./color.nix { inherit lib; };
  schemes = import ./schemes/default.nix;

  base16Keys = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  # Attrset keys are case-sensitive, and the base16 standard (plus stylix and
  # every tool that consumes it) spells the hex digits upper-case.
  isBaseKey = name: lib.elem name base16Keys;

  onlyBaseKeys = attrs: lib.filterAttrs (name: _: isBaseKey name) attrs;

  # ── Semantic roles ─────────────────────────────────────────────────────
  #
  # This mapping is THE contract: every `colors.<role>` a module reads
  # ultimately traces back to the base16 slot chosen here. Adding a role is
  # safe and backwards-compatible; renaming one is not.
  deriveRoles =
    p:
    let
      mix = color.mix;
      desat = color.desaturate;
    in
    {
      # ── Surfaces, darkest to lightest ────────────────────────────────
      background = p.base00;
      surface = p.base01;
      backgroundAlt = p.base01;
      backgroundPanel = p.base01;
      backgroundElement = p.base02;
      backgroundHover = mix p.base02 p.base03 0.5;
      backgroundActive = mix p.base02 p.base03 1.0;
      backgroundSelected = mix p.base02 p.base0D 0.28;

      # ── Text, brightest to dimmest ───────────────────────────────────
      foreground = p.base05;
      foregroundMuted = p.base04;
      foregroundSubtle = p.base03;

      # ── Borders ─────────────────────────────────────────────────────
      border = p.base03;
      borderSubtle = p.base02;
      borderStrong = p.base04;
      borderActive = p.base0D;

      # ── Accents & status ────────────────────────────────────────────
      accent = p.base0D;
      accentAlt = p.base0C;
      accentMuted = desat p.base0D 0.5;

      success = p.base0B;
      warning = p.base09;
      error = p.base08;
      info = p.base0C;

      # ── Interaction ─────────────────────────────────────────────────
      cursor = p.base07;
      selection = mix p.base02 p.base0D 0.35;
      selectionText = p.base05;

      # ── Diff / VCS ──────────────────────────────────────────────────
      diffAdded = p.base0B;
      diffRemoved = p.base08;
      diffModified = p.base09;

      # ── Syntax ──────────────────────────────────────────────────────
      syntaxKeyword = p.base0E;
      syntaxFunction = p.base0D;
      syntaxString = p.base0B;
      syntaxNumber = p.base09;
      syntaxType = p.base0C;
      syntaxComment = p.base03;
      syntaxOperator = p.base0A;
    };

  # The 16 ANSI colours a terminal needs. Built from the resolved roles, so a
  # role override on `accent` propagates all the way into the terminal.
  deriveTerminal =
    r:
    let
      # "bright" variants nudge the base colour toward the foreground, which is
      # the conventional way to build an ANSI bright variant from a base16
      # palette that has no dedicated slots for them.
      brighten = c: color.mix c r.foreground 0.25;
    in
    {
      inherit (r) background foreground cursor selection selectionText;

      black = r.background;
      red = r.error;
      green = r.success;
      yellow = r.warning;
      blue = r.accent;
      magenta = r.syntaxKeyword;
      cyan = r.accentAlt;
      white = r.foreground;

      brightBlack = r.foregroundMuted;
      brightRed = brighten r.error;
      brightGreen = brighten r.success;
      brightYellow = brighten r.warning;
      brightBlue = brighten r.accent;
      brightMagenta = brighten r.syntaxKeyword;
      brightCyan = brighten r.accentAlt;
      brightWhite = r.foreground;
    };

  # Which base16 counterpart, if any, sits at the other polarity within the
  # same family. Lets `preferences.darkMode` flip the whole system without a
  # second explicit setting.
  oppositeVariant =
    chosen:
    let
      names = builtins.attrNames schemes;
      want =
        if chosen.polarity == "dark" then
          lib.filter (n: schemes.${n}.polarity == "light") names
        else
          lib.filter (n: schemes.${n}.polarity == "dark") names;
    in
    lib.findFirst (n: schemes.${n}.family == chosen.family) null want;

  # Look a scheme up by key, falling back to the system default rather than
  # throwing. `didFallback` lets the module layer raise a real assertion.
  resolveScheme =
    requested:
    let
      fallback = "catppuccin-mocha";
    in
    {
      requested = requested;
      resolvedKey = if schemes ? ${requested} then requested else fallback;
      didFallback = !(schemes ? ${requested});
      palette = schemes.${if schemes ? ${requested} then requested else fallback};
    };

  mkColors =
    { scheme ? "catppuccin-mocha"
    , overrides ? { }
    ,
    }:
    let
      sel = resolveScheme scheme;
      raw = sel.palette;

      # Metadata with sane fallbacks, so a hand-written scheme file only has
      # to get `base00`-`base0F` right.
      meta = {
        slug = raw.slug or sel.resolvedKey;
        name = raw.name or sel.resolvedKey;
        family = raw.family or "custom";
        variant = raw.variant or "default";
        polarity = raw.polarity or (if color.isDark raw.base00 then "dark" else "light");
      };

      # Pass 1 — base overrides replace the raw palette; roles re-derive.
      palette' = raw // onlyBaseKeys overrides;

      # Pass 2 — role overrides win outright.
      roles = (deriveRoles palette') // lib.filterAttrs (n: _: !(isBaseKey n)) overrides;

      terminal = deriveTerminal roles;

      # stylix takes `attrs` (verified against stylix/palette.nix:113), so the
      # hashless palette plus name/variant is a valid base16Scheme.
      base16 = overlay [
        (lib.mapAttrs (_: v: color.toBase16 v) (onlyBaseKeys palette'))
        {
          inherit (meta) slug name variant;
        }
      ];

      # A text colour guaranteed legible on the resolved background.
      onBackground = color.bestForeground roles.background [
        roles.foreground
        roles.foregroundMuted
        "#ffffff"
        "#000000"
      ];
    in
    overlay [
      meta
      (onlyBaseKeys palette')
      roles
      {
        inherit
          terminal
          base16
          onBackground
          color
          base16Keys
          ;
        requested = sel.requested;
        resolvedKey = sel.resolvedKey;
        didFallback = sel.didFallback;
        isDark = color.isDark roles.background;
        oppositeKey = oppositeVariant meta;
      }
    ];
in
{
  inherit
    color
    schemes
    mkColors
    base16Keys
    resolveScheme
    ;

  # The raw catalog, keyed by name — the input to `mkColors`. Exposed so a
  # module layer can show what a scheme looks like before resolving roles.
  available = schemes;

  schemeNames = builtins.attrNames schemes;

  # Schemes grouped by polarity — what a theme picker UI wants.
  dark = lib.filter (n: schemes.${n}.polarity == "dark") (builtins.attrNames schemes);
  light = lib.filter (n: schemes.${n}.polarity == "light") (builtins.attrNames schemes);

  # name -> human-readable label, for pickers and assertion messages.
  labels = lib.mapAttrs (_: s: s.name) schemes;

  # Every role name the resolver can produce, for documentation and tests.
  roleNames = builtins.attrNames (mkColors { });
}
