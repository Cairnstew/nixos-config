# =============================================================================
# tests/theme-literals_test.nix — the hex-literal ratchet
# =============================================================================
# Phase 5 of docs/decisions/2026-11-13-theme-nix.md: stop hardcoded palettes
# from creeping back into modules.
#
# Rule: no `#rrggbb` / `#rrggbbaa` literal in `modules/**/*.nix` except where
# colours are *defined*:
#
#   * `*/theme.nix`            — the per-app theme side-cars (Phases 1-3)
#   * `*/theming/`             — the palette modules themselves
#   * `modules/flake-parts/theming.nix` — the flake-level scheme/override layer
#
# plus an explicit brand allow-list (values that are identity, not palette).
#
# It also refuses to pass vacuously: a second test asserts the scan actually
# reached the module tree (see GOTCHAS "coverage test must prove what it
# discovered" — an empty input list makes every `expected = [ ]` test green).
# =============================================================================
{ lib, repoRoot, ... }:

let
  roots = [
    "modules/nixos"
    "modules/home"
    "modules/flake-parts"
  ];

  dirPath = rel: repoRoot + "/${rel}";

  entriesOf = rel: builtins.readDir (dirPath rel);

  # Every `.nix` file under a root, recursively.
  nixFiles =
    rel:
    let
      entries = entriesOf rel;
      names = builtins.attrNames entries;
      isDir = n: entries.${n} == "directory";
      isNix = n: entries.${n} == "regular" && lib.hasSuffix ".nix" n;
    in
    map (n: "${rel}/${n}") (builtins.filter isNix names)
    ++ lib.concatMap (n: nixFiles "${rel}/${n}") (builtins.filter isDir names);

  files = lib.concatMap nixFiles roots;

  # Where hex values are allowed to be defined.
  isDefinitionSite =
    rel:
    lib.hasSuffix "/theme.nix" rel
    || lib.hasInfix "/theming/" rel
    || rel == "modules/flake-parts/theming.nix";

  # Deliberately fixed colours (brand identity, not palette). Stripped before
  # matching so a line carrying only the brand colour is clean.
  brand = [
    "#1db954" # Spotify green (waybar widget, spotify theming)
    "#1DB954"
  ];

  stripBrand = line: lib.replaceStrings brand (map (_: "") brand) line;

  # `#rrggbb` or `#rrggbbaa`, but not `nixpkgs#404663` (a word character before
  # the `#`) and not a longer run of hex digits.
  isHex =
    line:
    let
      s = stripBrand line;
      tail = "([^0-9a-fA-F]|$).*";
    in
    builtins.match "^#[0-9a-fA-F]{6}${tail}" s != null
    || builtins.match "^#[0-9a-fA-F]{8}${tail}" s != null
    || builtins.match ".*[^0-9A-Za-z_#]#[0-9a-fA-F]{6}${tail}" s != null
    || builtins.match ".*[^0-9A-Za-z_#]#[0-9a-fA-F]{8}${tail}" s != null;

  offenders =
    file:
    lib.concatLists (
      lib.imap1
        (i: line: lib.optional (isHex line) "${file}:${toString i}")
        (lib.splitString "\n" (builtins.readFile (dirPath file)))
    );

  scanned = builtins.filter (f: !(isDefinitionSite f)) files;
  violations = lib.concatMap offenders scanned;
in
{
  suites."theme-literals" = {
    pos = __curPos;
    tests = [
      {
        name = "no-hex-literals-outside-theme-files";
        type = "unit";
        expected = [ ];
        actual = violations;
      }

      {
        name = "scan-reaches-the-module-tree";
        type = "unit";
        expected = true;
        actual =
          builtins.length scanned > 100
          && builtins.any (f: lib.hasSuffix "/theme.nix" f) files
          && builtins.elem "modules/nixos/hyprland/bar/theme.nix" files
          && !(builtins.elem "modules/nixos/hyprland/bar/theme.nix" scanned);
      }
    ];
  };
}
