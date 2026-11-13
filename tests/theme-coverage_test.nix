# =============================================================================
# tests/theme-coverage_test.nix — `meta.theme` <-> `theme.nix` invariants
# =============================================================================
# Enforces the contract in docs/decisions/2026-11-13-theme-nix.md §3.4/§3.5:
#
#   * a module that ships theme.nix must say so in meta.nix
#   * a module that declares theme.nix in meta.nix must actually have the file
#   * theme.nix must be reachable from the module entrypoint (default.nix, or
#     home.nix for the Home-Manager side of a NixOS module)
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

  moduleDirs =
    root:
    let
      entries = builtins.readDir (repoRoot + "/${root}");
      names = builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries);
    in
    map (n: "${root}/${n}") names;

  dirs = lib.concatMap moduleDirs roots;

  dirPath = rel: repoRoot + "/${rel}";

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
