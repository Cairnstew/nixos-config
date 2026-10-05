# =============================================================================
# thunderstore.nix — ThunderStore pack tooling at the flake level
# =============================================================================
# Purpose: expose the hash-pinned ThunderStore workflow as flake outputs. Packs
#          live in modules/home/thunderstore/packs/<name>/ (an authored pack.json,
#          a generated game.json snapshot of the ecosystem schema, and a generated
#          checksums.json pin file) and become fixed-output derivations exactly
#          like music playlists and packwiz modpacks.
#
# Outputs (perSystem, one set per pack directory):
#   - packages."thunderstore-pack-<name>"  → the built, routed profile
#   - apps."thunderstore-install-<name>"   → build + install into the Steam game dir
#   - apps."thunderstore-plan-<name>"      → dry run: print every write and prune
#
# Plus three generic apps:
#   - apps."thunderstore-game-info"        → inspect the ecosystem model for a game
#   - apps."thunderstore-sync"             → freeze a game's ecosystem entry into game.json
#   - apps."thunderstore-checksums"        → download + pin every package into checksums.json
#
# Usage:
#   mkdir -p modules/home/thunderstore/packs/<name>       # new pack
#   # author modules/home/thunderstore/packs/<name>/pack.json:
#   #   { "name": "<name>", "game": "lethal-company",
#   #     "mods": { "x753-Mimics": "2.7.4", "notnotnotswipez-MoreCompany": "1.14.0" } }
#   git add modules/home/thunderstore/packs/<name>/pack.json   # flakes only see tracked files
#   nix run .#thunderstore-game-info -- lethal-company          # check the model first
#   nix run .#thunderstore-sync -- <name>                       # → game.json
#   nix run .#thunderstore-checksums -- <name>                 # → checksums.json
#   nix build .#thunderstore-pack-<name>                        # verify pinned bytes
#   nix run .#thunderstore-plan-<name>                          # dry run
#   nix run .#thunderstore-install-<name>                       # write into the game dir
#
# Everything runs from the LIVE working tree (the apps re-read the pack
# directory), so a pack can be iterated without re-locking the flake. All three
# apps must be run from the repo root.
# =============================================================================

{ inputs, lib, ... }:

let
  inherit (inputs) self;

  packsDir = "${self}/modules/home/thunderstore/packs";
  packNames =
    if builtins.pathExists packsDir then
      builtins.attrNames
        (
          lib.filterAttrs (_: type: type == "directory") (builtins.readDir packsDir)
        )
    else
      [ ];

  apiScript = ./thunderstore-api.py;
  syncScript = ./thunderstore-sync.py;
  checksumsScript = ./thunderstore-checksums.py;

  # The shared pack builder, wired to one pack directory.
  buildPack = pkgs: name:
    import ../home/thunderstore/lib/pack.nix {
      inherit pkgs lib;
      packDir = "${packsDir}/${name}";
      inherit name;
    };

  # `lib.getExe` adds the executable bit to the store path; a bare toString of a
  # writeShellScriptBin path fails with "Permission denied" at `nix run`.
  mkGameInfoApp = pkgs: {
    program = lib.getExe (
      pkgs.writeShellScriptBin "thunderstore-game-info" ''
        set -euo pipefail
        export PATH=${pkgs.coreutils}/bin:${pkgs.gnused}/bin:$PATH
        exec ${pkgs.python3}/bin/python3 ${apiScript} "$@"
      ''
    );
  };

  # ── generic: freeze a game's ecosystem entry into <pack>/game.json ─────────
  mkSyncApp = pkgs: {
    program = lib.getExe (
      pkgs.writeShellScriptBin "thunderstore-sync" ''
        set -euo pipefail
        if [ ! -f flake.nix ]; then
          echo "thunderstore-sync: run this from the repo root" >&2
          exit 1
        fi
        export THUNDERSTORE_API=${apiScript}
        export THUNDERSTORE_PACKS_DIR=${packsDir}
        exec ${pkgs.python3}/bin/python3 ${syncScript} "$@"
      ''
    );
  };

  # ── generic: download + pin every package into <pack>/checksums.json ───────
  mkChecksumsApp = pkgs: {
    program = lib.getExe (
      pkgs.writeShellScriptBin "thunderstore-checksums" ''
        set -euo pipefail
        if [ ! -f flake.nix ]; then
          echo "thunderstore-checksums: run this from the repo root" >&2
          exit 1
        fi
        export PATH=${pkgs.coreutils}/bin:${pkgs.gnused}/bin:$PATH
        export THUNDERSTORE_API=${apiScript}
        export THUNDERSTORE_PACKS_DIR=${packsDir}
        exec ${pkgs.python3}/bin/python3 ${checksumsScript} "$@"
      ''
    );
  };

  # ── per pack: install into the discovered Steam game directory ─────────────
  # The pack derivation ships lib/install.sh beside its manifest, so the app is
  # a two-line wrapper. Steam discovery happens at run time, never at eval time.
  mkInstallApp = pkgs: name:
    let
      built = buildPack pkgs name;
    in
    {
      program = lib.getExe (
        pkgs.writeShellScriptBin "thunderstore-install-${name}" ''
          set -euo pipefail
          export PATH=${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnused}/bin:$PATH
          exec ${built.routing}/install.sh ${built.routing}/manifest.json "$@"
        ''
      );
    };

  # ── per pack: dry run ─────────────────────────────────────────────────────
  mkPlanApp = pkgs: name:
    let
      built = buildPack pkgs name;
    in
    {
      program = lib.getExe (
        pkgs.writeShellScriptBin "thunderstore-plan-${name}" ''
          set -euo pipefail
          export PATH=${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnused}/bin:$PATH
          exec ${built.routing}/install.sh ${built.routing}/manifest.json --dry-run "$@"
        ''
      );
    };

in
{
  perSystem = { pkgs, ... }: {
    packages = lib.listToAttrs
      (
        map (name: lib.nameValuePair "thunderstore-pack-${name}" (buildPack pkgs name).package) packNames
      )
    // {
      # End-to-end test for the install-rule router (fixtures, no network).
      "thunderstore-router-test" = import ../home/thunderstore/lib/router-test.nix {
        inherit lib pkgs;
      };
    };

    apps = lib.listToAttrs
      (
        lib.concatMap
          (name: [
            (lib.nameValuePair "thunderstore-install-${name}" (mkInstallApp pkgs name))
            (lib.nameValuePair "thunderstore-plan-${name}" (mkPlanApp pkgs name))
          ])
          packNames
      )
    // {
      "thunderstore-game-info" = mkGameInfoApp pkgs;
      "thunderstore-sync" = mkSyncApp pkgs;
      "thunderstore-checksums" = mkChecksumsApp pkgs;
    };
  };
}
