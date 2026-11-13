# =============================================================================
# tests/theme-coverage_test.nix — `meta.theme` <-> `theme.nix` invariants
# =============================================================================
# Enforces the contract in docs/decisions/2026-11-13-theme-nix.md §3.4/§3.5:
#
#   * a module that ships theme.nix must say so in meta.nix
#   * a module that declares theme.nix in meta.nix must actually have the file
#   * theme.nix must be reachable from the module entrypoint (default.nix, or
#     home.nix for the Home-Manager side of a NixOS module)
#
# The scan is recursive: nested submodules (e.g. modules/nixos/hyprland/bar)
# ship their own theme.nix and their own minimal meta.nix theme record.
#   * a module recorded as `mechanism = "none"` must not ship theme.nix
#
# It runs against the flake source (`inputs.self`), so files must be staged
# before `nix` sees them — the same rule as every other flake evaluation.
# =============================================================================
{ lib, repoRoot, ... }:

let
  roots = [
    "modules/nixos"
    "modules/home"
  ];

  dirPath = rel: repoRoot + "/${rel}";

  entriesOf = rel: builtins.readDir (dirPath rel);

  subdirs = rel:
    builtins.filter
      (n: (entriesOf rel).${n} == "directory")
      (builtins.attrNames (entriesOf rel));

  # A directory is a module directory when it has an entrypoint or an option
  # declaration. Nested submodules (hyprland/bar, …) count too: their theme.nix
  # carries the same contract as a top-level module's.
  isModuleDir = rel:
    builtins.any (f: builtins.pathExists (dirPath rel + "/${f}")) [
      "default.nix"
      "options.nix"
    ];

  # Recurse unconditionally: `modules/nixos` itself has no entrypoint, so
  # stopping at non-module directories would never reach the modules below it.
  moduleDirs =
    root:
    let
      walk =
        rel:
        (if isModuleDir rel then [ rel ] else [ ])
        ++ lib.concatMap (n: walk "${rel}/${n}") (subdirs rel);
    in
    walk root;

  dirs = lib.concatMap moduleDirs roots;

  hasTheme = rel: builtins.pathExists (dirPath rel + "/theme.nix");

  metaOf =
    rel:
    let
      path = dirPath rel + "/meta.nix";
    in
    if builtins.pathExists path then import path else { };

  declared =
    rel:
    let
      meta = metaOf rel;
    in
      meta.theme.file or null;

  entryFiles =
    rel:
    builtins.filter (f: builtins.pathExists (dirPath rel + "/${f}")) [
      "default.nix"
      "home.nix"
    ];

  importsTheme =
    rel:
    builtins.any
      (
        f: lib.hasInfix "./theme.nix" (builtins.readFile (dirPath rel + "/${f}"))
      )
      (entryFiles rel);

  withTheme = builtins.filter hasTheme dirs;
  declaresTheme = builtins.filter (rel: declared rel == "theme.nix") dirs;
in
{
  suites."theme-coverage" = {
    pos = __curPos;
    tests = [
      {
        name = "every-theme-nix-is-declared-in-meta";
        type = "unit";
        expected = [ ];
        actual = builtins.filter (rel: declared rel != "theme.nix") withTheme;
      }

      {
        name = "every-meta-declared-theme-nix-exists";
        type = "unit";
        expected = [ ];
        actual = builtins.filter (rel: !(hasTheme rel)) declaresTheme;
      }

      {
        name = "theme-nix-is-imported-by-its-entrypoint";
        type = "unit";
        expected = [ ];
        actual = builtins.filter (rel: !(importsTheme rel)) withTheme;
      }

      {
        name = "theme-nix-is-absent-when-mechanism-is-none";
        type = "unit";
        expected = [ ];
        actual = builtins.filter
          (
            rel: ((metaOf rel).theme.mechanism or null) == "none" && hasTheme rel
          )
          dirs;
      }
    ];
  };
}
