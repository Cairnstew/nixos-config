# =============================================================================
# router-test.nix — end-to-end test for lib/route.py
# =============================================================================
# Builds a synthetic BepInEx pack out of fixtures at build time (no network, no
# Steam install), unzips it, routes it through route.py, and asserts the exact
# destination layout — so install-rule routing, rootFolder stripping, override
# folders, flattening and hash recording are all honest.
#
# Built as packages."thunderstore-router-test" by modules/flake-parts/thunderstore.nix:
#   nix build .#thunderstore-router-test
{ lib, pkgs }:

let
  # Lethal Company's real install rules — the assertions below check against these.
  bepinexRules = [
    {
      route = "BepInEx/plugins";
      defaultFileExtensions = [ ".dll" ];
      trackingMethod = "subdir";
      isDefaultLocation = true;
    }
    {
      route = "BepInEx/core";
      defaultFileExtensions = [ ];
      trackingMethod = "subdir";
      isDefaultLocation = false;
    }
    {
      route = "BepInEx/patchers";
      defaultFileExtensions = [ ];
      trackingMethod = "subdir";
      isDefaultLocation = false;
    }
    {
      route = "BepInEx/monomod";
      defaultFileExtensions = [ ".mm.dll" ];
      trackingMethod = "subdir";
      isDefaultLocation = false;
    }
    {
      route = "BepInEx/config";
      defaultFileExtensions = [ ];
      trackingMethod = "none";
      isDefaultLocation = false;
    }
  ];

  spec = pkgs.writeText "thunderstore-router-spec.json" (builtins.toJSON {
    loader = "bepinex";
    installRules = bepinexRules;
    pack = {
      name = "router-test";
      game = "lethal-company";
    };
    game = {
      label = "lethal-company";
      steamAppId = "1966720";
      steamFolderName = "Lethal Company";
      dataFolderName = "Lethal Company_Data";
      packageLoader = "bepinex";
    };
    loaders = import ./loaders.nix { inherit lib; };
    relativeFileExclusions = null;
    allowConflicts = false;
    profileDir = "profile";
    planOut = "install-plan.json";
    manifestOut = "routed.json";
    entries = [
      {
        kind = "loader";
        id = "BepInEx-BepInExPack-5.4.2305";
        modName = "BepInExPack";
        rootFolder = "BepInExPack";
        srcDir = "zips/loader";
        dependencies = [ ];
      }
      {
        kind = "mod";
        id = "Test-Fixture-1.0.0";
        modName = "Fixture";
        rootFolder = "";
        srcDir = "zips/mod";
        dependencies = [ ];
      }
    ];
  });
in
pkgs.runCommand "thunderstore-router-test"
{
  nativeBuildInputs = [
    pkgs.python3
    pkgs.unzip
    pkgs.zip
    pkgs.jq
  ];
}
  ''
    set -euo pipefail
    export HOME="$TMPDIR"
    work=$(mktemp -d)
    cd "$work"

    # Fixture 1: a BepInEx payload nested under rootFolder exactly like the real
    # BepInEx-BepInExPack zip (BepInExPack/BepInEx/core/..., BepInExPack/.doorstop_version),
    # with ThunderStore's base metadata files at the ZIP ROOT, outside rootFolder.
    mkdir -p stage/BepInExPack/BepInEx/core stage/BepInExPack/BepInEx/plugins zips
    echo bepinex-core > stage/BepInExPack/BepInEx/core/BepInEx.dll
    echo doorstop-cfg > stage/BepInExPack/doorstop_config.ini
    echo 5.4.2305 > stage/BepInExPack/.doorstop_version
    echo '{}' > stage/manifest.json
    echo readme > stage/README.md
    echo png > stage/icon.png
    ( cd stage && zip -qr "$work/loader.zip" BepInExPack manifest.json README.md icon.png )
    unzip -q loader.zip -d zips/loader

    # Fixture 2: a mod with a root dll, a nested lib dir and an override folder.
    mkdir -p stage2/lib stage2/override
    echo mod-main > stage2/Fixture.dll
    echo mod-helper > stage2/lib/Helper.dll
    echo override-dll > stage2/override/Overridden.dll
    echo readme > stage2/README.txt
    ( cd stage2 && zip -qr "$work/mod.zip" . )
    unzip -q mod.zip -d zips/mod

    cp ${spec} spec.json
    ${pkgs.python3}/bin/python3 ${./route.py} spec.json

    fail() {
      echo "thunderstore router test: $1" >&2
      echo "--- produced tree ---" >&2
      find profile -type f | sort >&2
      exit 1
    }

    # 1. ThunderStore's base metadata files never reach the game directory
    #    (they sit at the zip root, outside rootFolder, so stripping drops them)
    test -e profile/gameRoot/manifest.json && fail "manifest.json must not be installed"
    test -e profile/gameRoot/README.md && fail "README.md must not be installed"
    test -e profile/gameRoot/icon.png && fail "icon.png must not be installed"
    # 2. rootFolder stripping worked (the payload is not nested twice)
    test -d profile/gameRoot/BepInExPack && fail "rootFolder was not stripped"
    test -f profile/gameRoot/BepInEx/core/BepInEx.dll || fail "loader core missing"
    test -f profile/gameRoot/doorstop_config.ini || fail "loader payload root missing"
    test -f profile/gameRoot/.doorstop_version || fail "loader dotfile missing"
    # 3. `subdir` tracking flattens a root .dll into <route>/<ModName>/
    test -f profile/gameRoot/BepInEx/plugins/Fixture/Fixture.dll || fail "mod dll not routed"
    # 4. ... while a top-level `override/` folder keeps its nesting
    test -f profile/gameRoot/BepInEx/plugins/Fixture/override/Overridden.dll \
      || fail "override folder lost its nesting"
    # 5. a nested file flattens by basename, not by path
    test -f profile/gameRoot/BepInEx/plugins/Fixture/Helper.dll || fail "nested dll not flattened"
    # 6. files matching no extension rule fall through to the default route
    test -f profile/gameRoot/BepInEx/plugins/Fixture/README.txt || fail "default route not used"

    # 7. the plan records both hash forms plus a chmod-ready mode for every file
    ${pkgs.jq}/bin/jq -e '.files | length == 7' install-plan.json > /dev/null \
      || fail "expected 7 routed files"
    ${pkgs.jq}/bin/jq -e \
      'all(.files[]; (.sha256Hex | test("^[0-9a-f]{64}$")) and (.sha256 | startswith("sha256-")) and (.mode | test("^0[0-7]{3}$")))' \
      install-plan.json > /dev/null || fail "hashes or modes missing from the plan"
    ${pkgs.jq}/bin/jq -e 'all(.files[]; .dest == "gameRoot")' install-plan.json > /dev/null \
      || fail "every routed file should target gameRoot for bepinex"
    ${pkgs.jq}/bin/jq -e '.conflicts | length == 0' install-plan.json > /dev/null \
      || fail "unexpected install conflicts"

    echo "thunderstore router test: OK"
    touch $out
  ''
